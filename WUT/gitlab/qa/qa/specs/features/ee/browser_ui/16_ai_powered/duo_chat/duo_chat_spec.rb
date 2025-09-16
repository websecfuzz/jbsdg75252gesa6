# frozen_string_literal: true

module QA
  # https://docs.gitlab.com/ee/development/ai_features/duo_chat.html
  RSpec.describe 'Ai-powered', product_group: :duo_chat do
    describe 'Duo Chat' do
      let(:user) { Runtime::User::Store.test_user }
      let(:api_client) { Runtime::User::Store.default_api_client }
      let(:token) { api_client.personal_access_token }
      let(:project) { create(:project, name: 'duo-chat-project', api_client: api_client) }

      shared_examples 'Duo Chat' do |testcase|
        it 'a valid response is returned', testcase: testcase do
          QA::EE::Page::Component::DuoChat.perform do |duo_chat|
            duo_chat.open_duo_chat
            duo_chat.clear_chat_history
            duo_chat.send_duo_chat_prompt('hi')

            Support::Waiter.wait_until(message: 'Wait for Duo Chat response and feedback message') do
              raise "Error found in Duo Chat: '#{duo_chat.error_text}'" if duo_chat.has_error?

              duo_chat.number_of_messages > 1 && duo_chat.has_feedback_message?
            end

            QA::Runtime::Logger.debug("Latest Duo Chat response #{duo_chat.latest_response}")
            expect(duo_chat.latest_response).not_to be_empty, "Expected a response from Duo Chat"
          end
        end
      end

      before do
        Flow::Login.sign_in(as: user)
        project.visit!
      end

      context "when asking 'hi'" do
        context 'on GitLab.com', :external_ai_provider,
          only: { pipeline: %i[staging staging-canary canary production] } do
          include_examples 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/441192'
        end

        context 'on Self-managed', :orchestrated, :ai_gateway do
          let(:api_client) { Runtime::User::Store.admin_api_client }
          let(:user) { Runtime::User::Store.admin_user }

          include_examples 'Duo Chat', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/464684'
        end
      end
    end
  end
end
