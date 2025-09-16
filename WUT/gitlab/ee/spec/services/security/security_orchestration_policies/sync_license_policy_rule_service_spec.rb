# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::SyncLicensePolicyRuleService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let_it_be(:security_policy) { create(:security_policy) }
  let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read) }
  let_it_be(:approval_policy_rule) do
    create(:approval_policy_rule, :license_finding, security_policy: security_policy)
  end

  let_it_be(:software_license_policy) do
    create(:software_license_policy, project: project, approval_policy_rule: approval_policy_rule)
  end

  let(:license_types) { %w[BSD MIT] }

  let(:service) do
    described_class.new(
      project: project,
      security_policy: security_policy,
      approval_policy_rule: approval_policy_rule,
      scan_result_policy_read: scan_result_policy_read
    )
  end

  describe '#execute' do
    before do
      approval_policy_rule.content['license_types'] = license_types
      approval_policy_rule.save!
    end

    it 'calls create service for each license type' do
      create_service = instance_double(SoftwareLicensePolicies::CreateService)

      expect(SoftwareLicensePolicies::CreateService)
        .to receive(:new)
        .twice
        .and_return(create_service)
      expect(create_service).to receive(:execute).twice

      service.execute
    end

    it 'creates software license policies' do
      service.execute

      expect(project.software_license_policies.count).to eq(license_types.size)
      license_types.each_with_index do |license_type, i|
        expect(project.software_license_policies[i].name).to eq(license_type)
        expect(project.software_license_policies[i].approval_status).to eq('denied')
        expect(project.software_license_policies[i].approval_policy_rule_id).to eq(approval_policy_rule.id)
      end
    end

    it 'deletes existing software license policies' do
      service.execute

      expect { software_license_policy.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
