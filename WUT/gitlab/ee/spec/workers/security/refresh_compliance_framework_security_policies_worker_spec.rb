# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Security::RefreshComplianceFrameworkSecurityPoliciesWorker, feature_category: :security_policy_management do
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:namespace) { create(:group, parent: root_namespace) }
  let_it_be(:other_namespace) { create(:group, parent: root_namespace) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:project_policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: nil, namespace: namespace)
  end

  let_it_be(:other_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: nil, namespace: other_namespace)
  end

  let_it_be(:compliance_framework) { create(:compliance_framework, namespace: root_namespace) }
  let_it_be(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy,
      policy_configuration: policy_configuration,
      framework: compliance_framework
    )
  end

  let_it_be(:project_compliance_framework_security_policy) do
    create(:compliance_framework_security_policy,
      policy_configuration: project_policy_configuration,
      framework: compliance_framework
    )
  end

  let(:compliance_framework_changed_event) do
    ::Projects::ComplianceFrameworkChangedEvent.new(data: {
      project_id: project.id,
      compliance_framework_id: compliance_framework.id,
      event_type: ::Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added]
    })
  end

  before do
    allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
      allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
    end
  end

  it 'invokes Security::ProcessScanResultPolicyWorker with the project_id and configuration_id' do
    expect(Security::ProcessScanResultPolicyWorker).to receive(:perform_async).once.with(project.id,
      policy_configuration.id)
    expect(Security::ProcessScanResultPolicyWorker).to receive(:perform_async).with(project.id,
      project_policy_configuration.id)
    expect(Security::ProcessScanResultPolicyWorker).not_to receive(:perform_async).with(project.id,
      other_policy_configuration.id)

    consume_event(subscriber: described_class, event: compliance_framework_changed_event)
  end

  context 'with security_policies' do
    let_it_be(:security_policy) do
      create(:security_policy,
        security_orchestration_policy_configuration: policy_configuration,
        scope: { compliance_frameworks: [{ id: compliance_framework.id }] }
      )
    end

    let_it_be(:deleted_security_policy) do
      create(:security_policy, :deleted,
        security_orchestration_policy_configuration: policy_configuration,
        scope: { compliance_frameworks: [{ id: compliance_framework.id }] }
      )
    end

    let_it_be(:project_security_policy) do
      create(:security_policy,
        security_orchestration_policy_configuration: project_policy_configuration,
        scope: { compliance_frameworks: [{ id: compliance_framework.id }] }
      )
    end

    let_it_be(:other_security_policy) do
      create(:security_policy,
        security_orchestration_policy_configuration: other_policy_configuration,
        scope: { compliance_frameworks: [{ id: compliance_framework.id }] }
      )
    end

    before do
      create(:compliance_framework_project_setting,
        project: project,
        compliance_management_framework: compliance_framework
      )
    end

    it 'invokes Security::SecurityOrchestrationPolicies::SyncPolicyEventService for undeleted policies' do
      expect_next_instance_of(
        Security::SecurityOrchestrationPolicies::SyncPolicyEventService,
        project: project,
        security_policy: security_policy,
        event: an_instance_of(::Projects::ComplianceFrameworkChangedEvent)
      ) do |instance|
        expect(instance).to receive(:execute)
      end
      expect_next_instance_of(
        Security::SecurityOrchestrationPolicies::SyncPolicyEventService,
        project: project,
        security_policy: project_security_policy,
        event: an_instance_of(::Projects::ComplianceFrameworkChangedEvent)
      ) do |instance|
        expect(instance).to receive(:execute)
      end

      consume_event(subscriber: described_class, event: compliance_framework_changed_event)
    end
  end
end
