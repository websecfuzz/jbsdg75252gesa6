# frozen_string_literal: true

module Admin
  module Ai
    class DuoSelfHostedController < Admin::ApplicationController
      feature_category :"self-hosted_models"
      urgency :low

      before_action :ensure_feature_enabled!

      def index; end

      private

      def ensure_feature_enabled!
        render_404 unless Ability.allowed?(current_user, :manage_self_hosted_models_settings)
      end
    end
  end
end
