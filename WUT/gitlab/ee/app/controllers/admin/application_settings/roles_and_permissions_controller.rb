# frozen_string_literal: true

module Admin
  module ApplicationSettings
    class RolesAndPermissionsController < Admin::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper
      include ::EE::RolesAndPermissions # rubocop: disable Cop/InjectEnterpriseEditionModule -- EE-only concern
      include ProductAnalyticsTracking

      feature_category :user_management

      track_internal_event :new, name: 'view_admin_custom_roles_create_page', category: name
      track_internal_event :edit, name: 'view_admin_custom_roles_edit_page', category: name

      before_action :authorize_admin_member_roles!, except: [:index, :show]
      before_action :authorize_view_member_roles!, only: [:index, :show]

      before_action only: [:index] do
        push_frontend_feature_flag(:custom_admin_roles)
      end

      private

      def authorize_admin_member_roles!
        render_404 if gitlab_com_subscription? || !can?(current_user, :admin_member_role)
      end

      def authorize_view_member_roles!
        render_404 if gitlab_com_subscription? || !can?(current_user, :view_member_roles)
      end

      def tracking_namespace_source
        nil
      end

      def tracking_project_source
        nil
      end
    end
  end
end
