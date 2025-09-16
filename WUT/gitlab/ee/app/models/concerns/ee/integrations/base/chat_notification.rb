# frozen_string_literal: true

module EE
  module Integrations
    module Base
      module ChatNotification
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        EE_SUPPORTED_EVENTS = %w[vulnerability].freeze

        ::Integration.prop_accessor(*EE_SUPPORTED_EVENTS.map { |event| "#{event}_channel" })

        class_methods do
          extend ::Gitlab::Utils::Override

          override :supported_events
          def supported_events
            super + EE_SUPPORTED_EVENTS
          end
        end

        override :get_message
        def get_message(object_kind, data)
          return ::Integrations::ChatMessage::VulnerabilityMessage.new(data) if object_kind == 'vulnerability'

          super
        end
      end
    end
  end
end
