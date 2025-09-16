# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'approvalProjectRuleUpdate', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }
  let_it_be(:approvers) { create_list(:user, 3) }
  let_it_be(:groups) { create_list(:group, 2, :private) }

  let(:mutation_name) { 'approvalProjectRuleUpdate' }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }
  let(:id) { approval_project_rule.to_global_id.to_s }
  let(:name) { 'newname' }
  let(:approvals_required) { 4 }
  let(:mutation) do
    fields = all_graphql_fields_for('approvalProjectRuleUpdatePayload', max_depth: 4)
    graphql_mutation(mutation_name, params, fields)
  end

  let(:params) do
    {
      id: id,
      name: name,
      approvals_required: approvals_required,
      user_ids: approvers.pluck(:id),
      group_ids: groups.pluck(:id)
    }
  end

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(multiple_approval_rules: true)
  end

  context 'when the user does not have permission' do
    let_it_be(:approval_project_rule) { create(:approval_project_rule, project: project) }

    before_all do
      project.add_developer(current_user)
    end

    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create an approval project rule' do
      expect { post_mutation }.not_to change { ApprovalProjectRule.count }
    end
  end

  context 'when the user can update branch rules' do
    before_all do
      project.add_maintainer(current_user)
      project.add_developer(approvers.first)
      groups.first.add_developer(current_user)
      groups.first.add_developer(approvers.last)
    end

    shared_examples 'approval project rule update behavior' do
      it 'updates and returns the approval project rule' do
        post_mutation

        expect(mutation_response).to have_key('approvalRule')
        expect(mutation_response.dig('approvalRule', 'name')).to eq(name)
        expect(mutation_response.dig('approvalRule', 'approvalsRequired')).to eq(approvals_required)
        eligible_approver_ids = mutation_response.dig('approvalRule', 'eligibleApprovers', 'nodes').pluck('id')
        expected_ids = [approvers.first, approvers.last, current_user].map { |u| u.to_global_id.to_s }
        expect(eligible_approver_ids).to contain_exactly(*expected_ids)
        expect(mutation_response['errors']).to be_empty
      end

      context 'when the params are invalid' do
        before do
          # Create rule with name so name uniqueness validation will fail
          create(:approval_project_rule, project: project, name: name)
        end

        it 'returns an error' do
          post_mutation

          expect(mutation_response['errors'].first).to eq('Name has already been taken')
        end
      end
    end

    context 'when the approval rule is for a protected branch' do
      let_it_be(:approval_project_rule) do
        create(:approval_project_rule, project: project, protected_branches: [protected_branch])
      end

      it_behaves_like 'approval project rule update behavior' do
        it 'still applies to a protected branch' do
          post_mutation

          approval_project_rule.reload
          expect(approval_project_rule).not_to be_applies_to_all_protected_branches
          expect(approval_project_rule.protected_branches.count).to eq(1)
          expect(approval_project_rule.protected_branches.first).to eq(protected_branch)
        end
      end
    end

    context 'when the approval rule applies to all branches' do
      let_it_be(:approval_project_rule) { create(:approval_project_rule, project: project) }

      it_behaves_like 'approval project rule update behavior' do
        it 'still applies to all branches' do
          post_mutation

          approval_project_rule.reload
          expect(approval_project_rule).not_to be_applies_to_all_protected_branches
          expect(approval_project_rule.protected_branches).to be_empty
        end
      end
    end

    context 'when the apprvoal rule applies to all protected branches' do
      let_it_be(:approval_project_rule) do
        create(:approval_project_rule, project: project, applies_to_all_protected_branches: true)
      end

      it_behaves_like 'approval project rule update behavior' do
        it 'still applies to all protected branches' do
          post_mutation

          approval_project_rule.reload
          expect(approval_project_rule).to be_applies_to_all_protected_branches
        end
      end
    end

    context 'when approval rule cannot be found' do
      let(:id) { project.to_gid.to_s }
      let(:error_message) { %("#{id}" does not represent an instance of ApprovalProjectRule) }
      let(:global_id_error) { a_hash_including('message' => a_string_including(error_message)) }

      it 'returns an error' do
        post_mutation

        expect(graphql_errors).to include(global_id_error)
      end
    end
  end
end
