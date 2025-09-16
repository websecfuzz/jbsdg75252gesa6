# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ApprovalRules::CreateService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:author) { create(:user) }

  let_it_be_with_reload(:security_policy) do
    create(:security_policy,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration,
      content: {
        actions: [
          {
            type: 'require_approval',
            approvals_required: 1,
            user_approvers: ['admin']
          }
        ]
      }
    )
  end

  let_it_be_with_reload(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }
  let_it_be_with_reload(:approval_policy_rules) { [approval_policy_rule] }

  subject(:execute_service) do
    described_class.new(
      project: project,
      security_policy: security_policy,
      approval_policy_rules: approval_policy_rules,
      author: author
    ).execute
  end

  describe '#execute' do
    context 'when there are no approval actions' do
      before do
        security_policy.update!(content: { actions: [] })
      end

      it 'creates scan result policy read and approval rule' do
        expect { execute_service }
          .to change { project.scan_result_policy_reads.count }.by(1)
          .and change { project.approval_rules.count }.by(1)
      end

      context 'when rule type is any_merge_request' do
        before do
          approval_policy_rule.update!(
            type: Security::ApprovalPolicyRule.types[:any_merge_request],
            content: {
              type: 'any_merge_request',
              branches: [],
              commits: 'any'
            }
          )
        end

        it 'does not create approval rule' do
          expect { execute_service }.not_to change { project.approval_rules.count }
        end
      end
    end

    context 'when there are approval actions' do
      it 'creates scan result policy read and approval rule' do
        expect { execute_service }.to change { project.scan_result_policy_reads.count }.by(1)
          .and change { project.approval_rules.count }.by(1)
      end

      context 'when rule type is license_finding' do
        before do
          approval_policy_rule.update!(
            type: Security::ApprovalPolicyRule.types[:license_finding],
            content: {
              type: 'license_finding',
              match_on_inclusion_license: true,
              branches: [],
              license_states: ['newly_detected'],
              license_types: ['MIT']
            }
          )
        end

        it 'creates scan result policy read, software license policies and approval rule' do
          expect { execute_service }.to change { project.scan_result_policy_reads.count }.by(1)
            .and change { project.software_license_policies.count }.by(1)
            .and change { project.approval_rules.count }.by(1)
        end
      end
    end

    context 'when multiple approval policy rules exist' do
      let_it_be(:another_approval_policy_rule) do
        create(:approval_policy_rule, security_policy: security_policy)
      end

      let_it_be(:approval_policy_rules) { [approval_policy_rule, another_approval_policy_rule] }

      it 'creates rules and scan result policy reads for each policy' do
        expect { execute_service }
          .to change { project.approval_rules.count }.by(2)
          .and change { project.scan_result_policy_reads.count }.by(2)
      end
    end

    context 'when approval rule already exists' do
      let_it_be(:existing_approval_rule) do
        create(:approval_project_rule, project: project, approval_policy_rule: approval_policy_rule,
          approval_policy_action_idx: 0)
      end

      it 'does not create duplicate approval rule' do
        expect { execute_service }
          .to not_change { project.scan_result_policy_reads.count }
          .and not_change { project.approval_rules.count }
      end
    end

    context 'when scan_result_policy_read was already created' do
      before do
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          approval_policy_rule_id: approval_policy_rule.id,
          action_idx: 0
        )
      end

      it 'does not create duplicate scan result policy read or approval rule' do
        expect { execute_service }
          .to not_change { project.scan_result_policy_reads.count }
          .and not_change { project.approval_rules.count }
      end
    end

    context 'when approval rule creation fails' do
      before do
        allow_next_instance_of(::ApprovalRules::CreateService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'failed'))
        end
      end

      it 'logs the error with Gitlab::AppJsonLogger.debug' do
        expect(Gitlab::AppJsonLogger).to receive(:debug).with(hash_including(
          "event" => "approval_rule_creation_failed",
          "project_id" => project.id,
          "project_path" => project.full_path,
          "scan_result_policy_read_id" => an_instance_of(Integer),
          "approval_policy_rule_id" => approval_policy_rule.id,
          "action_index" => 0,
          "errors" => ['failed']
        ))

        execute_service
      end
    end
  end
end
