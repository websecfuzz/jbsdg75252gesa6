# frozen_string_literal: true

module QA
  RSpec.describe 'Growth', :requires_admin, only: { subdomain: :staging }, product_group: :acquisition do
    describe 'SaaS trials' do
      let(:api_client) { Runtime::API::Client.as_admin }
      let(:user) do
        create(:user, :hard_delete, email: "test-user-#{SecureRandom.hex(4)}@gitlab.com", api_client: api_client)
      end

      let(:group_for_trial) do
        Resource::Sandbox.fabricate! do |sandbox|
          sandbox.path = "test-group-fulfillment#{SecureRandom.hex(4)}"
          sandbox.api_client = api_client
        end
      end

      before do
        Flow::Login.sign_in(as: user)
        group_for_trial.visit!
      end

      describe 'starts a free trial' do
        context 'when visiting trials page with multiple eligible namespaces' do
          let!(:group) do
            Resource::Sandbox.fabricate! do |sandbox|
              sandbox.path = "test-group-fulfillment#{SecureRandom.hex(4)}"
              sandbox.api_client = api_client
            end
          end

          before do
            Runtime::Browser.visit(:gitlab, EE::Page::Trials::New)
          end

          it(
            'registers for a new trial',
            testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347671'
          ) do
            EE::Flow::Trial.register_for_trial(group: group_for_trial)

            Page::Group::Show.perform do |group|
              expect(group).to have_notice('You have successfully started an Ultimate and GitLab Duo Enterprise trial')
            end

            Page::Group::Menu.perform(&:go_to_billing)

            QA::EE::Page::Group::Settings::Billing.perform do |billing|
              expect do
                billing.billing_plan_header
              end.to eventually_include("#{group_for_trial.path} is currently using the Ultimate SaaS Trial Plan")
                       .within(max_duration: 120, max_attempts: 60, reload_page: page)
            end
          end
        end
      end
    end
  end
end
