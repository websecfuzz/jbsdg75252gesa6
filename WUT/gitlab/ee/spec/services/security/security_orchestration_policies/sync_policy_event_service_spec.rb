# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::SyncPolicyEventService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:compliance_framework) { create(:compliance_framework) }

  let(:policy_scope) { { compliance_frameworks: [{ id: compliance_framework.id }] } }
  let(:security_policy) do
    create(:security_policy, scope: policy_scope)
  end

  let(:service) do
    described_class.new(project: project, security_policy: security_policy, event: event)
  end

  before do
    create(:compliance_framework_project_setting,
      project: project,
      compliance_management_framework: compliance_framework
    )
  end

  subject(:execute) { service.execute }

  describe '#execute' do
    context 'when event is ComplianceFrameworkChangedEvent' do
      let(:event) do
        Projects::ComplianceFrameworkChangedEvent.new(data: {
          project_id: project.id,
          compliance_framework_id: compliance_framework.id,
          event_type: event_type
        })
      end

      shared_examples 'when policy scope does not match compliance_framework' do
        context 'when policy scope does not have compliance_framework' do
          let(:policy_scope) { {} }

          it 'does nothing' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end

        context 'when policy scope has a different compliance framework' do
          let_it_be(:other_compliance_framework) { create(:compliance_framework) }
          let(:policy_scope) { { compliance_frameworks: [{ id: other_compliance_framework.id }] } }

          it 'does nothing' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end
      end

      context 'when framework is added' do
        let(:event_type) { Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added] }

        it 'links policy to project' do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(1)

          expect(project.security_policies).to contain_exactly(security_policy)
        end

        it_behaves_like 'when policy scope does not match compliance_framework'

        it_behaves_like 'creates PEP project schedules' do
          before do
            security_policy.update!(scope: policy_scope)
          end
        end
      end

      context 'when framework is removed' do
        let(:event_type) { Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:removed] }

        context 'when policy is linked to the project' do
          before do
            create(:security_policy_project_link, project: project, security_policy: security_policy)
          end

          it 'unlinks policy from project' do
            expect { execute }.to change { Security::PolicyProjectLink.count }.by(-1)

            expect(project.reload.security_policies).to be_empty
          end
        end

        context 'when policy is not linked to the project' do
          it 'does nothing' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end

        it_behaves_like 'when policy scope does not match compliance_framework'
      end
    end

    context 'with protected branches event' do
      let(:protected_branch) { create(:protected_branch, project: project) }

      let(:sync_service) do
        instance_double(Security::SecurityOrchestrationPolicies::SyncProjectApprovalPolicyRulesService)
      end

      before do
        allow(Security::SecurityOrchestrationPolicies::SyncProjectApprovalPolicyRulesService)
          .to receive(:new)
          .and_return(sync_service)

        allow(sync_service).to receive(:update_rules)
      end

      context 'when event is ProtectedBranchCreatedEvent' do
        let(:event) do
          Repositories::ProtectedBranchCreatedEvent.new(data: {
            parent_id: project.id,
            parent_type: 'project',
            protected_branch_id: protected_branch.id
          })
        end

        context 'when there are no affected rules' do
          it 'does nothing' do
            expect(sync_service).not_to receive(:update_rules)
          end
        end

        context 'when there are affected rules' do
          let(:rules) do
            create_list(:approval_policy_rule, 2, security_policy: security_policy)
          end

          before do
            allow(sync_service).to receive(:protected_branch_ids).with(rules.first).and_return([protected_branch.id])
            allow(sync_service).to receive(:protected_branch_ids).with(rules.last).and_return([])
          end

          it 'updates the rules' do
            execute

            expect(sync_service).to have_received(:update_rules).with([rules.first])
          end
        end
      end

      context 'when event is ProtectedBranchDestroyedEvent' do
        let(:event) do
          Repositories::ProtectedBranchDestroyedEvent.new(data: { parent_id: project.id, parent_type: 'project' })
        end

        context 'when there are no affected rules' do
          it 'does nothing' do
            expect(sync_service).not_to receive(:update_rules)
          end
        end

        context 'when there are affected rules' do
          let!(:rules) do
            create_list(:approval_policy_rule, 2, security_policy: security_policy)
          end

          it 'updates the rules' do
            execute

            expect(sync_service).to have_received(:update_rules).with(rules)
          end
        end
      end
    end

    context 'when event is DefaultBranchChangedEvent' do
      let(:event) do
        Repositories::DefaultBranchChangedEvent.new(data: { container_id: project.id, container_type: 'Project' })
      end

      let(:sync_service) do
        instance_double(Security::SecurityOrchestrationPolicies::SyncProjectApprovalPolicyRulesService)
      end

      let!(:undeleted_rules) do
        create_list(:approval_policy_rule, 2, security_policy: security_policy)
      end

      let!(:deleted_rule) { create(:approval_policy_rule, security_policy: security_policy, rule_index: -1) }

      before do
        allow(Security::SecurityOrchestrationPolicies::SyncProjectApprovalPolicyRulesService)
          .to receive(:new)
          .and_return(sync_service)

        allow(sync_service).to receive(:update_rules)
      end

      it 'updates all undeleted rules' do
        execute

        expect(sync_service).to have_received(:update_rules).with(undeleted_rules)
      end
    end

    context 'when event is PolicyResyncEvent' do
      let(:event) { Security::PolicyResyncEvent.new(data: { security_policy_id: security_policy.id }) }

      let!(:policy_project_link) do
        create(:security_policy_project_link, project: project, security_policy: security_policy)
      end

      context 'when policy is linked to the project' do
        it 'unlinks and then links the policy to the project' do
          expect { execute }.not_to change { Security::PolicyProjectLink.count }
          expect { policy_project_link.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'when policy is not linked to the project' do
        before do
          policy_project_link.destroy!
        end

        it 'links the policy to the project' do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(1)

          expect(project.security_policies).to contain_exactly(security_policy)
        end
      end

      context 'when policy is not enabled' do
        before do
          security_policy.update!(enabled: false)
        end

        it 'deletes project link and does not create a new one' do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(-1)
        end
      end
    end
  end
end
