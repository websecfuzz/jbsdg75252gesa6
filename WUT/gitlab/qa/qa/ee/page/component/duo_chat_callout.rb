# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        module DuoChatCallout
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              view 'ee/app/assets/javascripts/ai/components/global_callout/duo_chat_callout.vue' do
                element 'duo-chat-promo-callout-popover'
              end
            end
          end

          def dismiss_duo_chat_popup
            return unless has_element?('duo-chat-promo-callout-popover', wait: 0.5)

            within_element('duo-chat-promo-callout-popover') do
              click_element('close-button')
            end
          end
        end
      end
    end
  end
end
