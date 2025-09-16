# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin mode', :js, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:role) { create(:admin_member_role, :read_admin_users, user: user) }

  context 'when using custom permissions' do
    context 'when custom_roles feature is available' do
      before do
        stub_licensed_features(custom_roles: true)

        gitlab_sign_in(user)
      end

      context 'when application setting :admin_mode is enabled', :request_store do
        it 'can enter admin mode via admin button' do
          visit root_dashboard_path

          click_link 'Admin'

          wait_for_requests

          fill_in 'user_password', with: user.password

          click_button 'Enter admin mode'

          expect(page).to have_current_path(admin_root_path)
        end

        context 'when in admin_mode' do
          before do
            enable_admin_mode!(user, use_ui: true)
          end

          it 'can access admin dashboard without entering admin mode' do
            visit root_dashboard_path

            click_link 'Admin'

            expect(page).to have_current_path(admin_root_path)
          end
        end
      end

      context 'when application setting :admin_mode is disabled' do
        before do
          stub_application_setting(admin_mode: false)
        end

        it 'can access admin dashboard without entering admin mode' do
          visit root_dashboard_path

          click_link 'Admin'

          expect(page).to have_current_path(admin_root_path)
        end
      end
    end

    context 'when custom_roles feature is not available' do
      before do
        stub_licensed_features(custom_roles: false)

        gitlab_sign_in(user)
      end

      it 'shows no admin buttons in navbar' do
        visit root_dashboard_path

        within '#super-sidebar' do
          expect(page).not_to have_link('Admin')
        end
      end
    end
  end
end
