# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        class DuoChat < QA::Page::Base
          view 'ee/app/assets/javascripts/ai/tanuki_bot/components/app.vue' do
            # components are derived from gitlab/ui
          end

          def open_duo_chat
            click_button('GitLab Duo Chat')
          end

          def send_duo_chat_prompt(prompt)
            fill_element('chat-prompt-input', prompt)
            click_element('paper-airplane-icon')
            wait_for_requests
          end

          def clear_chat_history
            send_duo_chat_prompt('/clear')
          end

          def empty_state?
            has_element?('gl-duo-chat-empty-state')
          end

          def latest_response
            Support::Retrier.retry_until(retry_on_exception: true, max_duration: 60) do
              find_all('.duo-chat-message p').last&.text.presence
            end
          end

          def has_feedback_message?
            has_css?('.duo-chat-message-feedback', wait: 30)
          end

          def has_error?
            has_css?('.has-error', wait: 1)
          end

          def error_text
            find_all('.has-error').map(&:text)
          end

          def number_of_messages
            find_all('.duo-chat-message').size
          end

          def close
            within_element('chat-header') do
              click_element('close-icon')
            end
          end

          def response
            find_element('chat-history').text
          end

          def duo_chat_open?
            has_element?('chat-prompt-input') && has_element?('chat-component')
          end

          def wait_for_response
            Support::Waiter.wait_until { find_all('.duo-chat-message').present? }
          end
        end
      end
    end
  end
end
