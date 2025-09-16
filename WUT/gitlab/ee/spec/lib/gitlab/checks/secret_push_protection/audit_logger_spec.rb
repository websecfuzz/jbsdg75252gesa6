# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretPushProtection::AuditLogger, feature_category: :secret_detection do
  include_context 'secrets check context'

  subject(:audit_logger) { described_class.new(project: project, changes_access: changes_access) }

  describe '#log_skip_secret_push_protection' do
    let(:comparison_path) do
      ::Gitlab::Utils.append_path(
        ::Gitlab::Routing.url_helpers.root_url,
        ::Gitlab::Routing.url_helpers.project_compare_path(project, from: initial_commit, to: new_commit)
      )
    end

    shared_examples 'audit event logging' do |skip_method|
      it "creates an audit event for #{skip_method} skip" do
        expect { audit_logger.log_skip_secret_push_protection(skip_method) }
          .to change { AuditEvent.count }.by(1)

        audit_event = AuditEvent.order(:id).last
        expect(audit_event.details[:custom_message]).to eq(
          "Secret push protection skipped via #{skip_method} on branch master"
        )
        expect(audit_event.details[:event_name]).to eq('skip_secret_push_protection')
        expect(audit_event.details[:target_details]).to eq(comparison_path)
        expect(audit_event.author_id).to eq(user.id)
        expect(audit_event.entity_id).to eq(project.id)
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'skip_secret_push_protection' }
        let(:namespace) { project.namespace }
        let(:label) { skip_method.to_s }
        let(:category) { "Gitlab::Checks::SecretPushProtection::AuditLogger" }
        subject { audit_logger.track_spp_skipped(skip_method.to_s) }
      end
    end

    it_behaves_like 'audit event logging', 'commit message'
    it_behaves_like 'audit event logging', 'push option'
  end

  describe '#log_exclusion_audit_event' do
    context 'with a path exclusion' do
      let(:exclusion) do
        create(:project_security_exclusion, :active, :with_path, project: project, value: "file-exclusion-1.rb")
      end

      it 'creates an audit event for applied exclusion' do
        expect { audit_logger.log_exclusion_audit_event(exclusion) }.to change { AuditEvent.count }.by(1)

        audit_event = AuditEvent.last
        expect(audit_event.details[:custom_message]).to eq(
          "An exclusion of type (path) with value (file-exclusion-1.rb) was applied in Secret push protection"
        )
        expect(audit_event.details[:event_name]).to eq('project_security_exclusion_applied')
        expect(audit_event.author_id).to eq(user.id)
      end
    end

    context 'with a rule exclusion' do
      let(:exclusion) do
        create(:project_security_exclusion, :active, :with_rule, project: project,
          value: "gitlab_personal_access_token")
      end

      it 'creates an audit event for applied exclusion' do
        expect { audit_logger.log_exclusion_audit_event(exclusion) }.to change { AuditEvent.count }.by(1)

        audit_event = AuditEvent.last
        expect(audit_event.details[:custom_message]).to eq(
          "An exclusion of type (rule) with value (gitlab_personal_access_token) was applied in Secret push protection"
        )
        expect(audit_event.details[:event_name]).to eq('project_security_exclusion_applied')
        expect(audit_event.author_id).to eq(user.id)
      end
    end
  end

  describe '#log_applied_exclusions_audit_events' do
    let(:exclusion1) do
      create(:project_security_exclusion, :active, :with_path, project: project, value: "file-exclusion-1.rb")
    end

    let(:exclusion2) do
      create(:project_security_exclusion, :active, :with_rule, project: project, value: "gitlab_personal_access_token")
    end

    let(:applied_exclusions) { [exclusion1, exclusion2] }

    it 'logs audit events for all applied exclusions' do
      expect { audit_logger.log_applied_exclusions_audit_events(applied_exclusions) }.to change {
        AuditEvent.count
      }.by(2)
    end
  end

  describe '#track_secret_found' do
    it_behaves_like 'internal event tracking' do
      let(:event) { 'detect_secret_type_on_push' }
      let(:namespace) { project.namespace }
      let(:label) { "gitlab_personal_access_token" }
      let(:category) { "Gitlab::Checks::SecretPushProtection::AuditLogger" }
      subject { super().track_secret_found('gitlab_personal_access_token') }
    end
  end

  describe '#get_project_security_exclusion_from_sds_exclusion' do
    let(:exclusion) { create(:project_security_exclusion, :with_rule, project: project) }

    let(:sds_exclusion) do
      Gitlab::SecretDetection::GRPC::Exclusion.new(
        exclusion_type: Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_RULE,
        value: exclusion.value
      )
    end

    it 'returns the same object if it is a ProjectSecurityExclusion' do
      result = audit_logger.send(:get_project_security_exclusion_from_sds_exclusion, exclusion)
      expect(result).to be exclusion
    end

    it 'returns the ProjectSecurityExclusion with the same value' do
      result = audit_logger.send(:get_project_security_exclusion_from_sds_exclusion, sds_exclusion)
      expect(result).to eq exclusion
    end
  end
end
