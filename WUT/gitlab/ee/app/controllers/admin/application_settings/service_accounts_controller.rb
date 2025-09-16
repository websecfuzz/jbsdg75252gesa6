# frozen_string_literal: true

module Admin
  module ApplicationSettings
    class ServiceAccountsController < Admin::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper

      feature_category :user_management

      before_action :authorize_admin_service_accounts!

      private

      def authorize_admin_service_accounts!
        render_404 if gitlab_com_subscription? || !can?(current_user, :admin_service_accounts)
      end
    end
  end
end
