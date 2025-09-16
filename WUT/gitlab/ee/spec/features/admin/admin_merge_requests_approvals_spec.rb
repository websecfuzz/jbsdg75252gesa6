# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin interacts with merge requests approvals settings', :js, feature_category: :source_code_management do
  include StubENV
  include Features::SecurityPolicyHelpers

  let_it_be(:user) { create(:admin) }
  let_it_be(:project) { create(:project, :repository, creator: user) }

  before do
    sign_in(user)
    enable_admin_mode!(user)

    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    allow(License).to receive(:feature_available?).and_return(true)

    visit(admin_push_rule_path)
  end

  it 'updates instance-level merge request approval settings and enforces project-level ones' do
    within_testid('merge-request-approval-settings') do
      check 'Prevent approval by author'
      check 'Prevent approvals by users who add commits'
      check _('Prevent editing approval rules in projects and merge requests')
      click_button('Save changes')
    end

    visit(admin_push_rule_path)

    expect(find_field('Prevent approval by author')).to be_checked
    expect(find_field('Prevent approvals by users who add commits')).to be_checked
    expect(find_field(_('Prevent editing approval rules in projects and merge requests'))).to be_checked

    visit project_settings_merge_requests_path(project)

    within_testid('merge-request-approval-settings') do
      expect(find('[data-testid="prevent-author-approval"] > input')).to be_disabled.and be_checked
      expect(find('[data-testid="prevent-committers-approval"] > input')).to be_disabled.and be_checked
      expect(find('[data-testid="prevent-mr-approval-rule-edit"] > input')).to be_disabled.and be_checked
    end
  end

  context 'when project has security policies' do
    let_it_be(:policy_management_project) { create(:project, :repository, namespace: project.namespace) }
    let_it_be(:policy) { create(:approval_policy) }
    let_it_be(:policy_name) { 'Deny MIT licenses' }
    let_it_be(:approver) { create(:user) }
    let_it_be(:approver_roles) { ['maintainer'] }
    let_it_be(:license_states) { %w[newly_detected] }
    let_it_be(:policy_branch_names) { %w[master] }

    before_all do
      project.add_developer(user)
      project.add_maintainer(approver)
      policy_management_project.add_developer(user)
    end

    before do
      stub_licensed_features(security_orchestration_policies: true)
      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: project)

      create_security_policy
    end

    it 'shows the security approvals', :sidekiq_inline do
      visit project_settings_merge_requests_path(project)
      wait_for_requests

      expect(page).to have_content('Security Approvals')
      expect(page).to have_content('Create more robust vulnerability rules and apply them to all your projects.')
      expect(page).to have_content(policy_name)
    end
  end
end
