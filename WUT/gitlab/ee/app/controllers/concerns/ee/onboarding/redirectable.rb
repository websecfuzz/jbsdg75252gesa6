# frozen_string_literal: true

module EE
  module Onboarding
    module Redirectable
      extend ::Gitlab::Utils::Override

      private

      def onboarding_first_step_path
        return unless ::Onboarding.enabled?

        users_sign_up_welcome_path
      end

      override :after_sign_up_path
      def after_sign_up_path
        if ::Onboarding.enabled?
          onboarding_first_step_path
        else
          super
        end
      end
    end
  end
end
