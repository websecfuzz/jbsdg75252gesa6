# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      module SelfHosted
        class AiGatewayUrlPresenceProbe < BaseProbe
          extend ::Gitlab::Utils::Override

          validate :check_ai_gateway_url_presence

          private

          def self_hosted_url
            ::Gitlab::AiGateway.self_hosted_url
          end

          def check_ai_gateway_url_presence
            return if self_hosted_url.present?

            errors.add(:base, failure_message)
          end

          override :success_message
          def success_message
            format(_(
              "Self hosted AI Gateway URL is set to %{url}. " \
                "It can be changed in the Gitlab Duo configuration."
            ), url: self_hosted_url)
          end

          def failure_message
            format(_(
              "Self hosted AI Gateway URL is not set. " \
                "It can be changed in the Gitlab Duo configuration." \
            ))
          end
        end
      end
    end
  end
end
