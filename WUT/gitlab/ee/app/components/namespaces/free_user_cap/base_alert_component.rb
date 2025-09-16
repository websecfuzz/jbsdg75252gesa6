# frozen_string_literal: true

module Namespaces
  module FreeUserCap
    class BaseAlertComponent < ViewComponent::Base
      # @param [Namespace or Group] namespace
      # @param [User] user
      # @param [String] content_class
      def initialize(namespace:, user:, content_class:)
        @namespace = namespace
        @user = user
        @content_class = content_class
      end

      private

      BLOG_URL = 'https://about.gitlab.com/blog/2022/03/24/efficient-free-tier'

      attr_reader :namespace, :user, :content_class

      def render?
        return false unless ::Namespaces::FreeUserCap.owner_access?(user: user, namespace: namespace)
        return false if dismissed?

        breached_cap_limit?
      end

      def breached_cap_limit?
        ::Namespaces::FreeUserCap::Enforcement.new(namespace).over_limit?
      end

      def variant
        :warning
      end

      def dismissible
        true
      end

      def dismissed?
        user.dismissed_callout_for_group?(feature_name: feature_name, group: namespace)
      end

      def alert_data
        return base_alert_data unless dismissible

        base_alert_data.merge(
          feature_id: feature_name,
          dismiss_endpoint: Rails.application.routes.url_helpers.group_callouts_path,
          group_id: namespace.id
        )
      end

      def base_alert_data
        {
          track_action: 'render',
          track_label: 'user_limit_banner',
          testid: 'user-over-limit-free-plan-alert'
        }
      end

      def close_button_data
        {
          track_action: 'dismiss_banner',
          track_label: 'user_limit_banner',
          testid: 'user-over-limit-free-plan-dismiss'
        }
      end

      def namespace_primary_cta
        render Pajamas::ButtonComponent.new(variant: :confirm, size: :medium,
          href: group_usage_quotas_path(namespace),
          button_options: {
            class: 'gl-alert-action',
            data: {
              track_action: 'click_button',
              track_label: 'manage_members',
              testid: 'user-over-limit-primary-cta'
            }
          }
        ) do
          _('Manage members')
        end
      end

      def namespace_secondary_cta
        render Pajamas::ButtonComponent.new(size: :medium,
          href: group_billings_path(namespace, source: 'user-limit-alert-enforcement'),
          button_options: {
            class: 'gl-alert-action',
            data: {
              track_action: 'click_button',
              track_label: 'explore_paid_plans',
              testid: 'user-over-limit-secondary-cta'
            }
          }
        ) do
          _('Explore paid plans')
        end
      end

      def link_end
        '</a>'.html_safe
      end

      def free_user_limit
        ::Namespaces::FreeUserCap.dashboard_limit
      end

      def blog_link_start
        "<a href='#{BLOG_URL}' target='_blank' rel='noopener noreferrer'>".html_safe
      end
    end
  end
end
