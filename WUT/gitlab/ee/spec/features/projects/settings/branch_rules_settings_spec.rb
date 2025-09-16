# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Settings > Repository > Branch rules settings', :js, feature_category: :source_code_management do
  include Spec::Support::Helpers::ModalHelpers
  include ListboxHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:branch_rule) do
    create(
      :protected_branch,
      code_owner_approval_required: true,
      allow_force_push: false
    )
  end

  let(:project) { branch_rule.project }

  before do
    project.add_maintainer(user)
    sign_in(user)
  end

  context 'when not licensed' do
    before do
      stub_licensed_features(merge_request_approvers: false, external_status_checks: false,
        multiple_approval_rules: false, protected_refs_for_users: false)
    end

    context 'with custom rule' do
      before do
        visit project_settings_repository_branch_rules_path(project, params: { branch: branch_rule.name })

        wait_for_requests
      end

      it 'does not render licensed feature additions' do
        page.within(find_by_testid('allowed-to-push-content')) do
          click_button 'Edit'
        end

        page.within('.gl-drawer') do
          expect(page).not_to have_css '[data-testid="users-selector"]', text: 'Users'
          expect(page).not_to have_css '[data-testid="groups-selector"]', text: 'Groups'
        end
      end

      it 'does not render licensed feature sections' do
        expect(page).not_to have_text 'Approval rules'
        expect(page).not_to have_css 'h2', text: 'Status checks'
      end
    end

    context 'with predefined rule' do
      it 'does not render predefined rules' do
        visit project_settings_repository_path(project)

        wait_for_requests

        click_button 'Add branch rule'

        expect(page).not_to have_content 'All protected branches'
      end
    end
  end

  context 'when licensed' do
    before do
      stub_licensed_features(merge_request_approvers: true, external_status_checks: true,
        multiple_approval_rules: true, protected_refs_for_users: true)
    end

    context 'with custom rule' do
      let!(:external_status_check) do
        create(:external_status_check, project: project, protected_branches: [branch_rule])
      end

      before do
        visit project_settings_repository_branch_rules_path(project, params: { branch: branch_rule.name })

        wait_for_requests
      end

      it 'renders rule details' do
        expect(page).to have_css 'h1', text: 'Branch rule details'
        expect(page).to have_css '[data-testid="branch"]', text: branch_rule.name
        expect(page).to have_css 'h2', text: 'Protect branch'
        expect(page).to have_text 'Allowed to push and merge'
        expect(page).to have_text 'Allowed to merge'
        expect(page).to have_text 'Approval rules'
        expect(page).to have_css 'h2', text: 'Status checks'
      end

      it 'renders users and groups selectors for branch protection' do
        page.within(find_by_testid('allowed-to-push-content')) do
          click_button 'Edit'
        end

        page.within('.gl-drawer') do
          expect(page).to have_css '[data-testid="users-selector"]', text: 'Users'
          expect(page).to have_css '[data-testid="groups-selector"]', text: 'Groups'
        end
      end

      it 'can edit branch protection' do
        page.within(find_by_testid('allowed-to-push-content')) do
          click_button 'Edit'
        end

        page.within('.gl-drawer') do
          check 'Administrators'
          page.within(find_by_testid('users-selector')) do
            find('.form-control').click
            first('.gl-new-dropdown-item').click
          end

          click_button 'Save changes'
        end

        wait_for_requests

        expect(page).to have_text 'Administrators'
        expect_avatar(user)
      end

      it 'can create status check' do
        within_testid('status-checks-table') do
          click_button('Add status check')
        end

        within_testid('status-checks-drawer') do
          fill_in 'Service name', with: 'QA'
          fill_in 'API to check', with: 'https://example.com'
          click_button('Save changes')
        end

        wait_for_requests

        within_testid('status-checks-table') do
          within_testid('crud-body') do
            expect(page).to have_content('QA')
            expect(page).to have_content('https://example.com')
          end
        end
      end

      it 'can update status check' do
        within_testid('status-checks-table') do
          click_button "Edit #{external_status_check.name}"
        end

        within_testid('status-checks-drawer') do
          fill_in 'Service name', with: 'QA'
          fill_in 'API to check', with: 'https://example2.com'
          click_button('Save changes')
        end

        wait_for_requests

        within_testid('status-checks-table') do
          within_testid('crud-body') do
            expect(page).to have_content('QA')
            expect(page).to have_content('https://example2.com')
          end
        end
      end

      it 'can delete status check' do
        within_testid('status-checks-table') do
          click_button "Delete"
        end

        click_button "Delete status check"

        wait_for_requests

        within_testid('status-checks-table') do
          within_testid('crud-body') do
            expect(page).not_to have_content(external_status_check.name)
            expect(page).not_to have_content(external_status_check.external_url)
          end
        end
      end

      it 'passes axe automated accessibility testing' do
        page.within(find_by_testid('allowed-to-merge-content')) do
          click_button 'Edit'
        end

        page.within('.gl-drawer') do
          expect(page).to be_axe_clean.skipping :'link-in-text-block'
        end
      end
    end
  end

  def expect_avatar(users)
    users = Array(users)

    members = page.all('[data-testid="allowed-to-push-content"] img.gl-avatar').pluck('alt')

    users.each do |user|
      expect(members).to include(user.name)
    end

    expect(members.size).to eq(users.size)
  end
end
