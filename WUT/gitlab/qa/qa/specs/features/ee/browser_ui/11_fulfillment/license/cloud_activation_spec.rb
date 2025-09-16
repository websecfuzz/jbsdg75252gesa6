# frozen_string_literal: true

module QA
  include Support::Helpers::Plan

  RSpec.describe 'Fulfillment', :requires_admin, :skip_live_env, :orchestrated, :cloud_activation,
    product_group: :provision do
    let(:user) { 'GitLab QA' }
    let(:company) { 'QA User' }
    let(:user_count) { 10_000 }
    let(:plan) { ULTIMATE_SELF_MANAGED }

    before do
      # As the screenshot may contain the sensitive information, it is being disabled for this test.
      Capybara::Screenshot.autosave_on_failure = false

      # Ensure the Gitlab instance does not already have an active license
      EE::Resource::License.delete_all

      Flow::Login.sign_in_as_admin

      Runtime::Browser.visit(:gitlab, EE::Page::Admin::Subscription)

      EE::Page::Admin::Subscription.perform do |subscription|
        # workaround for UI bug https://gitlab.com/gitlab-org/gitlab/-/issues/365305
        expect { subscription.has_no_active_subscription_title? }
          .to eventually_be_truthy.within(max_attempts: 60, reload_page: page)

        subscription.activate_license(Runtime::Env.ee_activation_code)
      end
    end

    after do
      EE::Resource::License.delete_all
      Capybara::Screenshot.autosave_on_failure = true
    end

    context 'Cloud activation code' do
      it 'activates instance with correct subscription details',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/350294' do
        EE::Page::Admin::Subscription.perform do |subscription|
          aggregate_failures do
            expect { subscription.subscription_details? }.to eventually_be_truthy.within(max_duration: 60)
            expect(subscription.name).to eq(user)
            expect(subscription.company).to include(company)
            expect(subscription.plan).to eq(plan[:name].capitalize)
            expect(subscription.users_in_subscription).to eq(user_count.to_s)
            expect(subscription).to have_subscription_record(plan, user_count, LICENSE_TYPE[:online_cloud])
          end
        end
      end
    end

    context 'Remove cloud subscription' do
      it 'successfully removes a cloud activation and shows flash notice',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/364831', quarantine: {
          type: :flaky,
          issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/505257'
        } do
        EE::Page::Admin::Subscription.perform do |subscription|
          subscription.remove_license_file

          expect { subscription.has_no_valid_license_alert? }
            .to eventually_be_truthy.within(max_duration: 60, max_attempts: 30)

          expect { subscription.has_no_active_subscription_title? }
            .to eventually_be_truthy.within(max_duration: 60, max_attempts: 30, reload_page: page)
        end
      end
    end
  end
end
