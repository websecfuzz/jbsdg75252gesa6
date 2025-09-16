# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::WelcomeController, feature_category: :onboarding do
  let_it_be(:user, reload: true) { create(:user, onboarding_in_progress: true, onboarding_status_email_opt_in: false) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }

  let(:onboarding_enabled?) { true }

  before do
    stub_saas_features(onboarding: onboarding_enabled?)
  end

  shared_examples 'user not in onboarding' do
    before do
      user.update!(onboarding_in_progress: false)
    end

    it { is_expected.to redirect_to(root_path) }
  end

  describe '#show' do
    let(:show_params) { {} }

    subject(:get_show) { get :show, params: show_params }

    context 'without a signed in user' do
      it { is_expected.to redirect_to new_user_registration_path }
    end

    context 'with signed in user' do
      before do
        sign_in(user)
      end

      it { is_expected.to render_template(:show) }

      it_behaves_like 'user not in onboarding'

      context 'when onboarding feature is not available' do
        let(:onboarding_enabled?) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when completed welcome step' do
        context 'when onboarding_status_setup_for_company is set to false' do
          before do
            user.update!(onboarding_status_setup_for_company: false)
            sign_in(user)
          end

          it { is_expected.to redirect_to(dashboard_projects_path) }
        end
      end

      context 'when 2FA is required from group' do
        before do
          user = create(:user, onboarding_in_progress: true, require_two_factor_authentication_from_group: true)
          sign_in(user)
        end

        it { is_expected.not_to redirect_to(profile_two_factor_auth_path) }
      end

      context 'when welcome step is completed' do
        before do
          user.update!(onboarding_status_setup_for_company: true)
        end

        context 'when user is confirmed' do
          before do
            sign_in(user)
          end

          it { is_expected.not_to redirect_to user_session_path }
        end

        context 'when user is not confirmed' do
          before do
            stub_application_setting_enum('email_confirmation_setting', 'hard')

            sign_in(user)

            user.update!(confirmed_at: nil)
          end

          it { is_expected.to redirect_to user_session_path }
        end
      end

      render_views

      it 'has the expected submission url' do
        get_show

        expect(response.body).to include("action=\"#{users_sign_up_welcome_path}\"")
      end
    end
  end

  describe '#update' do
    let(:joining_project) { 'false' }

    let(:onboarding_status_setup_for_company) { 'false' }
    let(:onboarding_status_role) { 0 }
    let(:onboarding_status_registration_objective) { 2 }

    let(:extra_params) { {} }
    let(:update_params) do
      {
        user: {
          registration_objective: 'code_storage',
          onboarding_status_joining_project: joining_project,
          onboarding_status_role: onboarding_status_role,
          onboarding_status_setup_for_company: onboarding_status_setup_for_company,
          onboarding_status_registration_objective: onboarding_status_registration_objective
        },
        jobs_to_be_done_other: '_jobs_to_be_done_other_',
        glm_source: 'some_source',
        glm_content: 'some_content'
      }.merge(extra_params)
    end

    subject(:patch_update) { patch :update, params: update_params }

    context 'without a signed in user' do
      it { is_expected.to redirect_to new_user_registration_path }
    end

    context 'with a signed in user' do
      before do
        sign_in(user)
      end

      it_behaves_like 'user not in onboarding'

      context 'when onboarding feature is not available' do
        let(:onboarding_enabled?) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'with email updates' do
        context 'when registration_objective field is provided' do
          it 'sets the registration_objective' do
            patch_update

            expect(controller.current_user.onboarding_status_registration_objective).to eq(2)
            expect(controller.current_user.onboarding_status_registration_objective_name).to eq("code_storage")
          end
        end
      end

      context 'with onboarding_status_role updates' do
        it 'sets the role in onboarding_status' do
          patch_update

          expect(user.onboarding_status_role_name).to eq('software_developer')
        end
      end

      context 'with registration_objective updates' do
        before do
          patch_update
        end

        it 'sets onboarding_status_registration_objective' do
          expect(user.onboarding_status_registration_objective_name).to eq('code_storage')
        end
      end

      context 'with onboarding_status_setup_for_company updates' do
        using RSpec::Parameterized::TableSyntax

        where(:onboarding_status_setup_for_company, :expected_status_value) do
          'true'  | true
          'false' | false
          nil     | false
        end

        with_them do
          before do
            patch_update
            user.reset
          end

          it 'sets the expected values for onboarding_status_setup_for_company field' do
            expect(user.onboarding_status_setup_for_company).to be expected_status_value
          end
        end
      end

      describe 'redirection' do
        context 'when onboarding is enabled' do
          it 'tracks successful submission event' do
            patch_update

            expect_snowplow_event(
              category: 'registrations:welcome:update',
              action: 'successfully_submitted_form',
              user: user,
              label: 'free_registration'
            )
          end

          it 'logs more info about the user update' do
            expect(Gitlab::AppLogger).to receive(:info).twice.and_call_original

            patch_update
          end

          it 'writes onboarding_in_progress to cache', :use_clean_rails_memory_store_caching do
            expect do
              patch_update
            end.to change { Rails.cache.read("user_onboarding_in_progress:#{user.id}") }.from(nil).to(true)
          end

          context 'when stop_welcome_redirection feature flag is disabled' do
            before do
              stub_feature_flags(stop_welcome_redirection: false)
            end

            it 'does not log for onboarding information' do
              expect(Gitlab::AppLogger).not_to receive(:info)

              patch_update
            end
          end

          context 'for environments without replicas' do
            it 'does not log' do
              allow(User.connection.load_balancer).to receive(:primary_write_location).and_raise(RuntimeError)
              expect(Gitlab::AppLogger).to receive(:info).once.and_call_original

              patch_update
            end
          end

          context 'when joining_project is "true"' do
            let(:joining_project) { 'true' }

            specify do
              patch_update
              user.reset

              expect(user.onboarding_in_progress).to be(false)
              expect(user.onboarding_status_joining_project).to be(true)
              expect(response).to redirect_to dashboard_projects_path
            end

            it 'tracks join a project event' do
              patch_update

              expect_snowplow_event(
                category: 'registrations:welcome:update',
                action: 'select_button',
                user: user,
                label: 'join_a_project'
              )
            end
          end

          context 'when joining_project is "false"' do
            it 'does not track join a project event' do
              patch_update

              expect_no_snowplow_event(
                category: 'registrations:welcome:update',
                action: 'select_button',
                user: user,
                label: 'join_a_project'
              )
            end

            context 'with group and project creation' do
              specify do
                patch_update
                user.reset
                path = new_users_sign_up_group_path

                expect(user.onboarding_in_progress).to be(true)
                expect(user.onboarding_status_joining_project).to be(false)
                expect(response).to redirect_to path
              end
            end
          end

          context 'when joining_project is not provided' do
            let(:update_params) do
              {
                user: {
                  onboarding_status_role: onboarding_status_role,
                  onboarding_status_setup_for_company: onboarding_status_setup_for_company
                }
              }
            end

            it 'defaults to creating a group' do
              patch_update
              user.reset
              path = new_users_sign_up_group_path

              expect(user.onboarding_in_progress).to be(true)
              expect(response).to redirect_to path
            end

            it 'does not track join a project event' do
              patch_update

              expect_no_snowplow_event(
                category: 'registrations:welcome:update',
                action: 'select_button',
                user: user,
                label: 'join_a_project'
              )
            end
          end

          context 'when setup_for_company is "true"' do
            let(:onboarding_status_setup_for_company) { 'true' }
            let(:trial_concerns) { {} }
            let(:redirect_path) { new_users_sign_up_company_path(expected_params) }
            let(:expected_params) do
              {
                jobs_to_be_done_other: '_jobs_to_be_done_other_'
              }
            end

            context 'when it is a trial registration' do
              before do
                user.update!(
                  onboarding_status_initial_registration_type: 'trial',
                  onboarding_status_registration_type: 'trial'
                )
              end

              it 'redirects to the company path and stores the url' do
                patch_update
                user.reset

                expect(user.onboarding_in_progress).to be(true)
                expect(user.onboarding_status_step_url).to eq(redirect_path)
                expect(user.onboarding_status_registration_type)
                  .to eq(::Onboarding::REGISTRATION_TYPE[:trial])
                expect(response).to redirect_to redirect_path
              end
            end

            context 'when it is not a trial registration' do
              before do
                user.update!(onboarding_status_initial_registration_type: 'free')
              end

              it 'redirects to the company path and stores the url' do
                patch_update
                user.reset

                expect(user.onboarding_in_progress).to be(true)
                expect(user.onboarding_status_step_url).to eq(redirect_path)
                expect(user.onboarding_status_registration_type)
                  .to eq(::Onboarding::REGISTRATION_TYPE[:trial])
                expect(response).to redirect_to redirect_path
              end
            end

            context 'when user is an invite registration' do
              it 'does not convert to a trial' do
                user.update!(onboarding_status_registration_type: 'invite')

                patch_update
                user.reset

                expect(user.onboarding_status_registration_type)
                  .not_to eq(::Onboarding::REGISTRATION_TYPE[:trial])
              end
            end

            context 'when user is a subscription registration' do
              context 'when detected from onboarding_status' do
                before do
                  user.update!(onboarding_status_registration_type: 'subscription')
                end

                it 'does not convert to a trial' do
                  patch_update
                  user.reset

                  expect(user.onboarding_status_registration_type)
                    .not_to eq(::Onboarding::REGISTRATION_TYPE[:trial])
                end
              end
            end
          end

          context 'when setup_for_company is "false"' do
            let(:onboarding_status_setup_for_company) { 'false' }

            specify do
              patch_update
              user.reset
              path = new_users_sign_up_group_path

              expect(user.onboarding_in_progress).to be(true)
              expect(user.onboarding_status_step_url).to eq(path)
              expect(user.onboarding_status_registration_type)
                .not_to eq(::Onboarding::REGISTRATION_TYPE[:trial])
              expect(response).to redirect_to path
            end

            context 'when it is a trial registration' do
              using RSpec::Parameterized::TableSyntax

              context 'when trial detected via onboarding_status' do
                before do
                  user.update!(
                    onboarding_status_initial_registration_type: 'trial', onboarding_status_registration_type: 'trial'
                  )
                end

                it 'redirects to the company path with expected db values' do
                  expected_params = {
                    jobs_to_be_done_other: '_jobs_to_be_done_other_'
                  }

                  patch_update
                  user.reset
                  path = new_users_sign_up_company_path(expected_params)

                  expect(user.onboarding_in_progress).to be(true)
                  expect(user.onboarding_status_step_url).to eq(path)
                  expect(user.onboarding_status_joining_project).to be(false)
                  expect(response).to redirect_to path
                end
              end
            end

            context 'when it is not a trial' do
              specify do
                patch_update
                user.reset
                path = new_users_sign_up_group_path

                expect(user.onboarding_in_progress).to be(true)
                expect(user.onboarding_status_step_url).to eq(path)
                expect(user.onboarding_status_joining_project).to be(false)
                expect(response).to redirect_to path
              end
            end
          end

          context 'when in subscription flow' do
            before do
              user.update!(onboarding_status_registration_type: 'subscription')
            end

            subject { patch :update, params: update_params }

            it { is_expected.not_to redirect_to new_users_sign_up_group_path }
          end

          context 'when in invitation flow' do
            let!(:member1) { create(:group_member, user: user) }

            before do
              user.update!(onboarding_status_registration_type: 'invite')
            end

            it { is_expected.not_to redirect_to new_users_sign_up_group_path }

            it 'tracks successful submission event' do
              patch_update

              expect_snowplow_event(
                category: 'registrations:welcome:update',
                action: 'successfully_submitted_form',
                user: user,
                label: 'invite_registration'
              )
            end

            it 'redirects to the group page' do
              expect(patch_update).to redirect_to(group_path(member1.source))
            end

            context 'when the new user already has more than 1 accepted group membership' do
              it 'redirects to the most recent membership group page' do
                member2 = create(:group_member, user: user)

                expect(patch_update).to redirect_to(group_path(member2.source))
              end
            end

            context 'when the member has an orphaned source at the time of the welcome' do
              it 'redirects to the project dashboard page' do
                member1.source.delete

                expect(patch_update).to redirect_to(dashboard_projects_path)
              end
            end
          end

          context 'when in trial flow' do
            before do
              user.update!(onboarding_status_registration_type: 'trial')
            end

            it { is_expected.not_to redirect_to new_users_sign_up_group_path }

            it 'tracks successful submission event' do
              patch_update

              expect_snowplow_event(
                category: 'registrations:welcome:update',
                action: 'successfully_submitted_form',
                user: user,
                label: 'trial_registration'
              )
            end
          end
        end

        context 'when failed request' do
          subject(:patch_update) do
            patch :update,
              params: {
                user: {
                  onboarding_status_role: onboarding_status_role,
                  onboarding_status_joining_project: 'true'
                }
              }
          end

          before do
            allow_next_instance_of(::Users::SignupService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'failed'))
            end
          end

          it 'does not track submission event' do
            patch_update

            expect_no_snowplow_event(
              category: 'registrations:welcome:update',
              action: 'successfully_submitted_form',
              user: user,
              label: 'free_registration'
            )
          end

          it 'does not track join a project event' do
            patch_update

            expect_no_snowplow_event(
              category: 'registrations:welcome:update',
              action: 'select_button',
              user: user,
              label: 'join_a_project'
            )
          end

          it 'track failed submission event' do
            patch_update

            expect_snowplow_event(
              category: 'registrations:welcome:update',
              action: 'track_free_registration_error',
              user: user,
              label: 'failed_submitting_form'
            )
          end
        end
      end
    end
  end
end
