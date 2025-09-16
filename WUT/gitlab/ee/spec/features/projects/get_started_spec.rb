# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Get started concerns', :js, :saas, :aggregate_failures, feature_category: :onboarding do
  include Features::InviteMembersModalHelpers
  include SubscriptionPortalHelpers

  context 'for Getting started page' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }
    let_it_be(:project) { create(:project, namespace: namespace) }

    context 'for overall rendering' do
      before_all do
        create(:onboarding_progress, namespace: namespace)
      end

      it 'renders sections correctly' do
        sign_in(user)

        visit namespace_project_get_started_path(namespace, project)

        within_testid('get-started-sections') do
          expect(page).to have_content('Quick start')
          expect(page).to have_content('Follow these steps to get familiar with the GitLab workflow.')
          expect(page).to have_content('Set up your code')
          expect(page).to have_content('Configure a project')
          expect(page).to have_content('Plan and execute work together')
          expect(page).to have_content('Secure your deployment')
        end
      end

      it 'invites a user and completes the invite action and updates the completion status' do
        sign_in(user)

        visit namespace_project_get_started_path(namespace, project)

        within_testid('static-items-section') do
          expect(page).to have_link('Get started 8%')
        end

        within_testid('get-started-sections') do
          expect(find_by_testid('progress-bar')).to have_selector('[aria-valuenow="8"]')
        end

        find_by_testid('section-header-1').click

        user_name_to_invite = create(:user).name

        within_testid('get-started-sections') do
          find_link('Invite your colleagues').click
        end

        stub_signing_key
        stub_reconciliation_request(true)
        stub_subscription_request_seat_usage(false)

        invite_with_opened_modal(user_name_to_invite)

        within_testid('get-started-page') do
          expect(page).to have_content('Your team is growing')
        end

        within_testid('get-started-sections') do
          expect(find_by_testid('progress-bar')).to have_selector('[aria-valuenow="15"]')
          expect(page).not_to have_link('Invite your colleagues')
        end

        within_testid('static-items-section') do
          expect(page).to have_link('Get started 15%')
        end
      end
    end

    context 'with completed links' do
      before do
        create(:onboarding_progress, namespace: namespace, code_added_at: Date.yesterday)
      end

      it 'renders correct completed sections' do
        sign_in(user)

        visit namespace_project_get_started_path(namespace, project)

        within_testid('get-started-sections') do
          expect_completed_section('Create a repository')
          expect_completed_section('Add code to a repository')
        end
      end
    end

    def expect_completed_section(text)
      expect(page).to have_no_link(text)
      expect(page).to have_content(text)
    end
  end
end
