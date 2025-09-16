# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FindingEntity, feature_category: :vulnerability_management do
  let_it_be(:user) { build(:user) }
  let_it_be_with_refind(:project) { create(:project) }

  let(:scanner) { build(:vulnerabilities_scanner, project: project) }

  let(:scan) { build(:ci_reports_security_scan) }

  let(:identifiers) do
    [
      build(:vulnerabilities_identifier),
      build(:vulnerabilities_identifier)
    ]
  end

  let(:flags) do
    [
      build(:vulnerabilities_flag)
    ]
  end

  let(:request) { double('request') }

  let(:vulnerabilities_finding) do
    build(
      :vulnerabilities_finding,
      scanner: scanner,
      scan: scan,
      project: project,
      identifiers: identifiers,
      vulnerability_flags: flags
    )
  end

  let(:pipeline) { build(:ee_ci_pipeline, :success, project: project) }

  let(:security_scan) do
    build(
      :security_scan,
      :latest_successful,
      project: project,
      pipeline: pipeline
    )
  end

  let(:security_finding) do
    build(
      :security_finding,
      :with_finding_data,
      false_positive: true,
      scan: security_scan
    )
  end

  describe '#as_json' do
    where(:occurrence) do
      [
        ref(:vulnerabilities_finding),
        ref(:security_finding)
      ]
    end
    with_them do
      let(:vulnerability) do
        build(
          :vulnerability,
          project: project,
          finding_id: occurrence.id
        )
      end

      let(:dismiss_feedback) do
        build(
          :vulnerability_feedback, :sast, :dismissal,
          project: project, uuid: occurrence.uuid
        )
      end

      let(:issue_feedback) do
        build(
          :vulnerability_feedback, :sast, :issue,
          project: project, uuid: occurrence.uuid
        )
      end

      let(:entity) do
        described_class.represent(occurrence, request: request)
      end

      subject do
        entity.as_json
      end

      before do
        stub_licensed_features(sast_fp_reduction: true)
        allow(request).to receive(:current_user).and_return(user)
      end

      it 'contains required fields' do
        expect(subject).to include(:id)
        expect(subject).to include(:name, :report_type, :severity)
        expect(subject).to include(:scanner, :project, :identifiers)
        expect(subject).to include(:dismissal_feedback, :issue_feedback)
        expect(subject).to include(:description, :links, :location, :remediations, :solution, :evidence)
        expect(subject).to include(:blob_path, :request, :response)
        expect(subject).to include(:scan)
        expect(subject).to include(:false_positive)
        expect(subject).to include(:assets, :evidence_source, :supporting_messages)
        expect(subject).to include(:uuid)
        expect(subject).to include(:details)
        expect(subject).to include(:found_by_pipeline)
        expect(subject).to include(:ai_resolution_enabled)
      end

      context 'false-positive' do
        it 'finds the vulnerability_finding as false_positive' do
          expect(subject[:false_positive]).to be(true)
        end

        it 'does not contain false_positive field if license is not available' do
          stub_licensed_features(sast_fp_reduction: false)

          expect(subject).not_to include(:false_positive)
        end
      end

      context 'when not allowed to admin vulnerability feedback' do
        before do
          project.add_guest(user)
        end

        it 'does not contain vulnerability feedback paths' do
          expect(subject[:create_jira_issue_url]).to be_falsey
          expect(subject[:create_vulnerability_feedback_issue_path]).to be_falsey
          expect(subject[:create_vulnerability_feedback_merge_request_path]).to be_falsey
          expect(subject[:create_vulnerability_feedback_dismissal_path]).to be_falsey
        end
      end

      context 'when allowed to admin vulnerability feedback' do
        before do
          project.add_developer(user)
        end

        it 'does not contain create jira issue path' do
          expect(subject[:create_jira_issue_url]).to be_falsey
        end

        it 'contains vulnerability feedback dismissal path' do
          expect(subject).to include(:create_vulnerability_feedback_dismissal_path)
        end

        it 'contains vulnerability feedback issue path' do
          expect(subject).to include(:create_vulnerability_feedback_issue_path)
        end

        it 'contains vulnerability feedback merge_request path' do
          expect(subject).to include(:create_vulnerability_feedback_merge_request_path)
        end

        context 'when jira service is configured' do
          let_it_be(:jira_integration) { create(:jira_integration, project: project, project_key: 'FE', vulnerabilities_enabled: true, vulnerabilities_issuetype: '10001') }

          before do
            stub_licensed_features(jira_vulnerabilities_integration: true)
            allow_next_found_instance_of(Integrations::Jira) do |jira|
              allow(jira).to receive(:jira_project_id).and_return('11223')
            end
          end

          it 'does contains create jira issue path' do
            expect(subject[:create_jira_issue_url]).to be_present
          end

          context 'and an external link to a Vulnerability is present' do
            let!(:external_issue_link) do
              create(
                :vulnerabilities_external_issue_link,
                vulnerability: vulnerability,
                author: user
              )
            end

            let(:reporter) do
              {
                'displayName' => 'reporter',
                'avatarUrls' => { '48x48' => 'http://reporter.avatar' },
                'name' => 'reporter@reporter.com'
              }
            end

            let(:assignee) do
              {
                'displayName' => 'assignee',
                'avatarUrls' => { '48x48' => 'http://assignee.avatar' },
                'name' => 'assignee@assignee.com'
              }
            end

            let(:jira_issue_attributes) do
              {
                summary: 'Title with <h1>HTML</h1>',
                created: '2020-06-25T15:39:30.000+0000',
                updated: '2020-06-26T15:38:32.000+0000',
                resolutiondate: '2020-06-27T13:23:51.000+0000',
                labels: ['backend'],
                fields: {
                  'reporter' => reporter,
                  'assignee' => assignee
                },
                project: {
                  key: 'GL'
                },
                key: 'GL-5',
                status: {
                  name: 'To Do'
                }
              }
            end

            let(:new_entity) { instance_double('Vulnerabilities::ExternalIssueLinkEntity') }

            before do
              occurrence.vulnerability = vulnerability
              allow(occurrence).to receive(:external_issue_links).and_return([external_issue_link])
              allow(Vulnerabilities::ExternalIssueLinkEntity).to receive(:new).and_return(new_entity)
              allow(new_entity).to receive(:presented).and_return(jira_issue_attributes)
            end

            it 'contains the external issue details' do
              expect(subject[:external_issue_links]).not_to be_empty
            end
          end
        end

        context 'when disallowed to create issue' do
          let_it_be(:project) { create(:project, issues_access_level: ProjectFeature::DISABLED) }

          it 'does not contain create jira issue path' do
            expect(subject[:create_jira_issue_url]).to be_falsey
          end

          it 'does not contain vulnerability feedback issue path' do
            expect(subject[:create_vulnerability_feedback_issue_path]).to be_falsey
          end

          it 'contains vulnerability feedback dismissal path' do
            expect(subject).to include(:create_vulnerability_feedback_dismissal_path)
          end

          it 'contains vulnerability feedback merge_request path' do
            expect(subject).to include(:create_vulnerability_feedback_merge_request_path)
          end
        end

        context 'when disallowed to create merge_request' do
          let_it_be(:project) { create(:project, merge_requests_access_level: ProjectFeature::DISABLED) }

          it 'does not contain create jira issue path' do
            expect(subject[:create_jira_issue_url]).to be_falsey
          end

          it 'does not contain vulnerability feedback merge_request path' do
            expect(subject[:create_vulnerability_feedback_merge_request_path]).to be_falsey
          end

          it 'contains vulnerability feedback issue path' do
            expect(subject).to include(:create_vulnerability_feedback_issue_path)
          end

          it 'contains vulnerability feedback dismissal path' do
            expect(subject).to include(:create_vulnerability_feedback_dismissal_path)
          end
        end
      end
    end
  end
end
