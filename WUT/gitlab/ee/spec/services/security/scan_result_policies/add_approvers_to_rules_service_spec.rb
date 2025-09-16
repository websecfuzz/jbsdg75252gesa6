# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::AddApproversToRulesService, feature_category: :security_policy_management do
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user_not_referenced_in_policy) { create(:user) }

  let_it_be(:namespace) do
    create(:group, :with_security_orchestration_policy_configuration)
  end

  let_it_be(:project1) { create(:project, :repository, group: namespace) }
  let_it_be(:project2) { create(:project, :repository, group: namespace) }
  let_it_be_with_reload(:merge_request1) { create(:merge_request, source_project: project1, target_project: project1) }

  let(:user_ids) { [user1.id, user2.id, user_not_referenced_in_policy.id] }
  let(:configuration) { namespace.security_orchestration_policy_configuration }
  let(:policies_yaml) do
    build(:orchestration_policy_yaml, approval_policy: [
      build(:approval_policy, name: 'Active policy', actions: [
        { type: 'require_approval', approvals_required: 1,
          user_approvers_ids: [user1.id], user_approvers: [user2.username] }
      ]),
      build(:approval_policy, name: 'Disabled policy', enabled: false, actions: [
        { type: 'require_approval', approvals_required: 1, user_approvers_ids: [user1.id] }
      ])
    ])
  end

  let(:policies_applicable_yaml) do
    build(:orchestration_policy_yaml, approval_policy: [
      build(:approval_policy, name: 'Active policy', actions: [
        { type: 'require_approval', approvals_required: 1,
          user_approvers_ids: [user1.id], user_approvers: [user2.username] }
      ]),
      build(:approval_policy, name: 'Active policy 2', enabled: true, actions: [
        { type: 'require_approval', approvals_required: 1, user_approvers_ids: [user1.id] }
      ])
    ])
  end

  let(:policies_not_applicable_yaml) do
    build(:orchestration_policy_yaml, approval_policy: [
      build(:approval_policy, name: 'Active policy',
        actions: [
          { type: 'require_approval', approvals_required: 1,
            user_approvers_ids: [user1.id], user_approvers: [user2.username] }
        ],
        policy_scope: {
          projects: {
            excluding: [{ id: project1.id }]
          }
        })
    ])
  end

  before do
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policies_yaml)
    end
  end

  describe '#execute' do
    let(:project_rule_expected_to_change) do
      create(:approval_project_rule, project: project1, security_orchestration_policy_configuration: configuration,
        orchestration_policy_idx: 0)
    end

    let!(:merge_request_rule_expected_to_change) do
      create(:approval_merge_request_rule, merge_request: merge_request1,
        security_orchestration_policy_configuration: configuration, orchestration_policy_idx: 0)
    end

    subject(:execute) { described_class.new(project: project1).execute(user_ids) }

    shared_examples_for 'adds users to the project rule' do
      it 'adds users to the project rule' do
        expect { execute }.to change { project_rule.users.count }.by(2)
        expect(project_rule.reload.users).to contain_exactly(user1, user2)
      end
    end

    shared_examples_for 'does not add users to the project rule' do
      it 'does not add users to the project rule' do
        expect { execute }.not_to change { project_rule.users.count }
      end
    end

    shared_examples_for 'adds users to the merge request rule' do
      it 'adds users to the merge request rule' do
        expect { execute }.to change { merge_request_rule.users.count }.by(2)
        expect(merge_request_rule.reload.users).to contain_exactly(user1, user2)
      end
    end

    shared_examples_for 'does not add users to the merge request rule' do
      it 'does not add users to the merge request rule' do
        expect { execute }.not_to change { merge_request_rule.users.count }
      end
    end

    context 'when users have access to the project' do
      before_all do
        project1.add_developer(user1)
        project1.add_developer(user2)
        project1.add_developer(user_not_referenced_in_policy)
      end

      describe 'project rules' do
        let!(:project_rule) { project_rule_expected_to_change }

        it_behaves_like 'adds users to the project rule'

        context 'when project rule belongs to a different policy index' do
          let!(:project_rule) do
            create(:approval_project_rule, project: project1,
              security_orchestration_policy_configuration: configuration, orchestration_policy_idx: 1)
          end

          it_behaves_like 'does not add users to the project rule'
        end

        context 'when project rule belongs to other configuration' do
          let_it_be(:configuration_other) do
            create(:security_orchestration_policy_configuration, project: project2)
          end

          let!(:project_rule) do
            create(:approval_project_rule, project: project1,
              security_orchestration_policy_configuration: configuration_other, orchestration_policy_idx: 0)
          end

          it_behaves_like 'does not add users to the project rule'
        end

        context 'when project rule belongs to other project' do
          let!(:project_rule) do
            create(:approval_project_rule, project: project2,
              security_orchestration_policy_configuration: configuration, orchestration_policy_idx: 0)
          end

          it_behaves_like 'does not add users to the project rule'
        end

        context 'when there are multiple project rules' do
          let(:policies_yaml) { policies_applicable_yaml }

          let!(:project_rule2) do
            create(:approval_project_rule,
              project: project1,
              security_orchestration_policy_configuration: configuration,
              orchestration_policy_idx: 0)
          end

          let!(:project_rule3) do
            create(:approval_project_rule,
              project: project1,
              security_orchestration_policy_configuration: configuration,
              orchestration_policy_idx: 1)
          end

          it 'adds users to the project rules' do
            expect { execute }
              .to change { project_rule.users.count }.by(2)
              .and change { project_rule2.users.count }.by(2)
              .and change { project_rule3.users.count }.by(1)

            expect(project_rule.reload.users).to contain_exactly(user1, user2)
            expect(project_rule2.reload.users).to contain_exactly(user1, user2)
            expect(project_rule3.reload.users).to contain_exactly(user1)
          end
        end

        context 'when policy is not applicable for the project' do
          let!(:project_rule) { project_rule_expected_to_change }
          let(:policies_yaml) { policies_not_applicable_yaml }

          it_behaves_like 'does not add users to the project rule'
        end
      end

      describe 'merge request rules' do
        let!(:merge_request_rule) { merge_request_rule_expected_to_change }

        it_behaves_like 'adds users to the merge request rule'

        context 'when merge request rule belongs to the project rule' do
          let!(:merge_request_rule) do
            create(:approval_merge_request_rule, merge_request: merge_request1,
              security_orchestration_policy_configuration: configuration, orchestration_policy_idx: 0,
              approval_project_rule: project_rule_expected_to_change)
          end

          it_behaves_like 'adds users to the merge request rule'
        end

        context 'when there are multiple merge requests in the project' do
          let(:policies_yaml) { policies_applicable_yaml }

          let(:merge_request2) do
            create(:merge_request, source_project: project1, target_project: project1, source_branch: 'test4')
          end

          let!(:merge_request_rule2) do
            create(:approval_merge_request_rule,
              merge_request: merge_request2,
              security_orchestration_policy_configuration: configuration,
              orchestration_policy_idx: 0,
              approval_project_rule: project_rule_expected_to_change
            )
          end

          let(:merge_request3) do
            create(:merge_request, source_project: project1, target_project: project1, source_branch: 'test5')
          end

          let!(:merge_request_rule3) do
            create(:approval_merge_request_rule,
              merge_request: merge_request3,
              security_orchestration_policy_configuration: configuration,
              orchestration_policy_idx: 1
            )
          end

          it 'adds users to the merge request rules' do
            expect { execute }
              .to change { merge_request_rule.users.count }.by(2)
              .and change { merge_request_rule2.users.count }.by(2)
              .and change { merge_request_rule3.users.count }.by(1)

            expect(merge_request_rule.reload.users).to contain_exactly(user1, user2)
            expect(merge_request_rule2.reload.users).to contain_exactly(user1, user2)
            expect(merge_request_rule3.reload.users).to contain_exactly(user1)
          end
        end

        context 'when merge request is merged' do
          let!(:merge_request_rule) { merge_request_rule_expected_to_change }

          before do
            merge_request1.mark_as_merged!
          end

          it_behaves_like 'does not add users to the merge request rule'
        end

        context 'when policies are not applicable to the project' do
          let!(:merge_request_rule) { merge_request_rule_expected_to_change }
          let(:policies_yaml) { policies_not_applicable_yaml }

          it_behaves_like 'does not add users to the merge request rule'
        end

        context 'when merge request rule belongs to a different policy index' do
          let!(:merge_request_rule) do
            create(:approval_merge_request_rule, merge_request: merge_request1,
              security_orchestration_policy_configuration: configuration, orchestration_policy_idx: 1)
          end

          it_behaves_like 'does not add users to the merge request rule'
        end

        context 'when merge request rule belongs to other configuration' do
          let_it_be(:configuration_other) do
            create(:security_orchestration_policy_configuration, project: project2)
          end

          let!(:merge_request_rule) do
            create(:approval_merge_request_rule, merge_request: merge_request1,
              security_orchestration_policy_configuration: configuration_other, orchestration_policy_idx: 0)
          end

          it_behaves_like 'does not add users to the merge request rule'
        end

        context 'when merge request rule belongs to a merge request in other project' do
          let_it_be(:merge_request2) { create(:merge_request, source_project: project2, target_project: project2) }
          let!(:merge_request_rule) do
            create(:approval_merge_request_rule, merge_request: merge_request2,
              security_orchestration_policy_configuration: configuration, orchestration_policy_idx: 0)
          end

          it_behaves_like 'does not add users to the merge request rule'
        end
      end
    end

    context 'when users do not have access to the project' do
      let!(:project_rule) { project_rule_expected_to_change }
      let!(:merge_request_rule) { merge_request_rule_expected_to_change }

      it_behaves_like 'does not add users to the project rule'
      it_behaves_like 'does not add users to the merge request rule'
    end
  end
end
