# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Settings::BranchRulesHelper, feature_category: :source_code_management do
  include Devise::Test::ControllerHelpers

  let_it_be(:project) { build_stubbed(:project) }

  describe '#branch_rules_data' do
    subject(:data) { helper.branch_rules_data(project) }

    before do
      stub_licensed_features(
        external_status_checks: true,
        merge_request_approvers: true,
        code_owner_approval_required: true,
        protected_refs_for_users: true
      )
    end

    it 'returns branch rules data' do
      expect(data).to match({
        project_path: project.full_path,
        protected_branches_path: project_settings_repository_path(project, anchor: 'js-protected-branches-settings'),
        approval_rules_path: project_settings_merge_requests_path(project,
          anchor: 'js-merge-request-approval-settings'),
        branch_rules_path: project_settings_repository_path(project, anchor: 'branch-rules'),
        status_checks_path: project_settings_merge_requests_path(project, anchor: 'js-merge-request-settings'),
        branches_path: project_branches_path(project),
        show_status_checks: 'true',
        show_approvers: 'true',
        show_code_owners: 'true',
        show_enterprise_access_levels: 'true',
        allow_multi_rule: 'false',
        can_edit: 'false',
        project_id: project.id,
        rules_path: expose_path(api_v4_projects_approval_rules_path(id: project.id)),
        can_admin_protected_branches: 'false'
      })
    end

    context 'when licensed features are disabled' do
      before do
        stub_licensed_features(
          external_status_checks: false,
          merge_request_approvers: false,
          code_owner_approval_required: false,
          protected_refs_for_users: false
        )
      end

      it 'returns the correct data' do
        expect(data).to include({
          show_status_checks: 'false',
          show_approvers: 'false',
          show_code_owners: 'false',
          show_enterprise_access_levels: 'false'
        })
      end
    end
  end
end
