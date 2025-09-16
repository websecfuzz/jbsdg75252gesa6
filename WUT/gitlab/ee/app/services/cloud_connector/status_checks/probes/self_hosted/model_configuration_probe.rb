# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      module SelfHosted
        # Performs a real request using the current user to verify that the Self-hosted configuration works.
        class ModelConfigurationProbe
          include ActiveModel::Validations
          include ActiveModel::Validations::Callbacks

          validate :check_user_exists
          validate :check_self_hosted_model_exists
          validate :validate_code_completion_availability

          attr_reader :self_hosted_model

          def initialize(user, self_hosted_model)
            @user = user
            @self_hosted_model = self_hosted_model
          end

          def execute
            return failure(failure_message) unless valid?

            success(success_message)
          end

          private

          attr_reader :user

          def success_message
            format(s_('AdminSelfHostedModels|Successfully connected to the self-hosted model'))
          end

          def check_user_exists
            errors.add(:base, _('User not provided')) unless user
          end

          def check_self_hosted_model_exists
            errors.add(:base, s_('AdminSelfHostedModels|Self-hosted model was not provided')) unless self_hosted_model
          end

          def validate_code_completion_availability
            return unless user

            error = ::Gitlab::Llm::AiGateway::CodeSuggestionsClient.new(user).test_model_connection(self_hosted_model)
            errors.add(:base, failure_text(error)) if error.present?
          end

          def failure_text(error)
            format(_('ERROR: %{error}'), error: error)
          end

          def details
            @details ||= ::CloudConnector::StatusChecks::Probes::BaseProbe::Details.new
          end

          def probe_name
            self.class.name.demodulize.underscore.to_sym
          end

          def success(message)
            create_result(true, message)
          end

          def failure(message)
            create_result(false, message)
          end

          def create_result(success, message)
            ::CloudConnector::StatusChecks::Probes::ProbeResult.new(probe_name, success, message, details, errors)
          end

          def failure_message
            errors.full_messages.first
          end
        end
      end
    end
  end
end
