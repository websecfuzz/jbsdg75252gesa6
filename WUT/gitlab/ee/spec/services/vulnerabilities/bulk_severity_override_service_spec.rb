# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkSeverityOverrideService, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:original_severity) { :high }
  let_it_be(:vulnerability) { create(:vulnerability, :with_findings, project: project, severity: original_severity) }
  let(:vulnerability_ids) { [vulnerability.id] }
  let(:comment) { "Severity needs to be updated." }
  let(:new_severity) { 'critical' }

  subject(:service) { described_class.new(user, vulnerability_ids, comment, new_severity) }

  describe '#execute' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
      stub_feature_flags(hide_vulnerability_severity_override: false)
    end

    context 'when the user is not authorized to update vulnerabilities from one of the projects' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_vulnerability) { create(:vulnerability, :with_findings, project: other_project) }
      let(:vulnerability_ids) { [vulnerability.id, other_vulnerability.id] }

      it 'raises an error' do
        expect { service.execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when vulnerability_severity_override feature flag is disabled' do
      before do
        stub_feature_flags(hide_vulnerability_severity_override: true)
      end

      it 'raises an error' do
        expect { service.execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when the user is authorized' do
      it_behaves_like 'sync vulnerabilities changes to ES' do
        let(:expected_vulnerabilities) { vulnerability }

        subject { service.execute }
      end

      context 'when system note' do
        using RSpec::Parameterized::TableSyntax

        where(
          :existing_note_severity,
          :existing_note_comment,
          :new_severity,
          :new_comment,
          :note_expected,
          :expected_note_text
        ) do
          [
            [
              'critical',
              'Severity needs to be updated.',
              'critical',
              'Severity needs to be updated.',
              false,
              nil
            ],
            [
              'critical',
              'Severity needs to be updated.',
              'critical',
              'Another comment',
              true,
              'changed comment to: "Another comment"'
            ],
            [
              'critical',
              'Severity needs to be updated.',
              'low',
              'Severity needs to be updated.',
              true,
              'changed vulnerability severity from High to Low with the following comment: ' \
                '"Severity needs to be updated."'
            ]
          ]
        end

        with_them do
          before do
            existing_note_text = ::SystemNotes::VulnerabilitiesService.formatted_note(
              'changed',
              existing_note_severity,
              nil,
              existing_note_comment,
              'severity',
              original_severity
            )

            create(
              :note,
              :system,
              noteable: vulnerability,
              project: project,
              note: existing_note_text
            )

            create(
              :note,
              :system,
              noteable: vulnerability,
              project: project,
              note: existing_note_text
            )

            vulnerability.update!(severity: existing_note_severity)
            vulnerability.reload
          end

          it 'creates a new system note only when needed' do
            new_service = described_class.new(user, [vulnerability.id], new_comment, new_severity)

            expect { new_service.execute }
              .to change { Note.count }
                    .by(note_expected ? 1 : 0)

            if note_expected
              last_note = Note.last
              expect(last_note.note).to eq(expected_note_text)
            end
          end
        end
      end

      it 'updates the severity for each vulnerability', :freeze_time do
        service.execute

        vulnerability.reload
        expect(vulnerability.severity).to eq(new_severity)
        expect(vulnerability.updated_at).to eq(Time.current)
      end

      it 'updates the severity for each vulnerability finding', :freeze_time do
        service.execute

        expect(vulnerability.finding.reload.severity).to eq(new_severity)
        expect(vulnerability.finding.reload.updated_at).to eq(Time.current)
      end

      it 'inserts a severity override record for each vulnerability' do
        expect { service.execute }.to change { Vulnerabilities::SeverityOverride.count }.by(vulnerability_ids.count)

        vulnerability.reload
        last_override = Vulnerabilities::SeverityOverride.last
        expect(last_override.vulnerability_id).to eq(vulnerability.id)
        expect(last_override.original_severity).to eq(original_severity.to_s)
        expect(last_override.new_severity).to eq(new_severity)
        expect(last_override.author).to eq(user)
      end

      it 'inserts a system note for each vulnerability' do
        expect { service.execute }.to change { Note.count }.by(vulnerability_ids.count)

        last_note = Note.last
        expect(last_note.noteable).to eq(vulnerability)
        expect(last_note.author).to eq(user)
        expect(last_note.project).to eq(project)
        expect(last_note.namespace_id).to eq(project.project_namespace_id)
        expect(last_note.note).to eq(
          "changed vulnerability severity from #{original_severity.to_s.titleize} to #{new_severity.titleize} " \
            "with the following comment: \"#{comment}\"")
        expect(last_note).to be_system

        last_system_note_metadata = SystemNoteMetadata.last
        expect(last_system_note_metadata.note_id).to eq(last_note.id)
        expect(last_system_note_metadata.action).to eq("vulnerability_severity_changed")
      end

      it 'returns a service response' do
        result = service.execute

        expect(result.payload[:vulnerabilities].count).to eq(vulnerability_ids.count)
      end

      it 'creates audit events for each vulnerability', :request_store do
        expect { service.execute }.to change { AuditEvent.count }.by(1)

        last_audit_event = AuditEvent.last&.details

        expect(last_audit_event[:name]).to eq('vulnerability_severity_override')
        expect(last_audit_event[:author_name]).to eq(user.name)
        expect(last_audit_event[:target_id]).to eq(project.id)
        expect(last_audit_event[:target_details]).to eq(
          ::Gitlab::Routing.url_helpers.project_security_vulnerability_url(project, vulnerability)
        )
        expect(last_audit_event[:custom_message]).to eq(
          "Vulnerability severity was changed from #{original_severity.to_s.titleize} to #{new_severity.capitalize}"
        )
      end

      it 'triggers an internal tracking event with success status', :clean_gitlab_redis_shared_state do
        expect { service.execute }.to trigger_internal_events('vulnerability_changed').with(
          category: described_class.name,
          project: project,
          namespace: namespace,
          user: user,
          additional_properties: {
            vulnerability_id: vulnerability.id,
            label: "vulnerability_change_severity",
            property: "success",
            old_value: original_severity.to_s,
            new_value: new_severity,
            field: "severity"
          }
        ).and increment_usage_metrics(
          'redis_hll_counters.count_distinct_namespace_id_from_vulnerability_changed_monthly',
          'redis_hll_counters.count_distinct_namespace_id_from_vulnerability_changed_weekly',
          'redis_hll_counters.count_distinct_user_id_from_vulnerability_changed_monthly',
          'redis_hll_counters.count_distinct_user_id_from_vulnerability_changed_weekly',
          'counts.count_total_vulnerability_changed_monthly',
          'counts.count_total_vulnerability_changed_weekly',
          'counts.count_total_vulnerability_changed'
        )
      end

      context 'when an error occurs during update' do
        before do
          allow(Vulnerabilities::SeverityOverride).to receive(:insert_all!)
            .and_raise(ActiveRecord::RecordNotUnique, 'override failed')
        end

        it 'returns an appropriate service response' do
          result = service.execute

          expect(result).to be_error
          expect(result.errors).to eq(['Could not modify vulnerabilities'])
        end

        it 'triggers an internal tracking event with error status',
          :clean_gitlab_redis_shared_state do
          expect { service.execute }.to trigger_internal_events('vulnerability_changed').with(
            category: described_class.name,
            project: project,
            namespace: namespace,
            user: user,
            additional_properties: {
              vulnerability_id: vulnerability.id,
              label: "vulnerability_change_severity",
              property: "error",
              old_value: original_severity.to_s,
              new_value: new_severity,
              field: "severity",
              error_message: "override failed"
            }
          ).and increment_usage_metrics(
            'redis_hll_counters.count_distinct_namespace_id_from_vulnerability_changed_monthly',
            'redis_hll_counters.count_distinct_namespace_id_from_vulnerability_changed_weekly',
            'redis_hll_counters.count_distinct_user_id_from_vulnerability_changed_monthly',
            'redis_hll_counters.count_distinct_user_id_from_vulnerability_changed_weekly',
            'counts.count_total_vulnerability_changed_monthly',
            'counts.count_total_vulnerability_changed_weekly',
            'counts.count_total_vulnerability_changed'
          )
        end
      end

      context 'when updating a large # of vulnerabilities' do
        let_it_be(:vulnerabilities) { create_list(:vulnerability, 2, :with_findings, project: project) }
        let_it_be(:vulnerability_ids) { vulnerabilities.map(&:id) }

        before do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:authorized_and_ff_enabled_for_all_projects?).and_return(true)
          end
        end

        it 'inserts a severity override record for each vulnerability' do
          expect { service.execute }.to change { Vulnerabilities::SeverityOverride.count }.by(vulnerability_ids.count)
        end

        it 'inserts a system note for the vulnerability' do
          expect { service.execute }.to change { Note.count }.by(vulnerability_ids.count)
        end

        it 'does not introduce N+1 queries' do
          control = ActiveRecord::QueryRecorder.new do
            described_class.new(user, vulnerability_ids, comment, new_severity).execute
          end

          new_vulnerability = create(:vulnerability, :with_findings)
          vulnerability_ids << new_vulnerability.id

          expect do
            described_class.new(user, vulnerability_ids, comment, new_severity).execute
          end.not_to exceed_query_limit(control)
        end
      end

      context 'when a vulnerability already has the new severity' do
        let_it_be(:vulnerability) { create(:vulnerability, :with_findings, :critical_severity, project: project) }

        it 'does not create severity override record' do
          expect { service.execute }.not_to change { Vulnerabilities::SeverityOverride.count }
        end

        it 'does not update a vulnerability' do
          expect { service.execute }.not_to change { vulnerability.reload.updated_at }
        end
      end
    end
  end
end
