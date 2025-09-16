# frozen_string_literal: true

module GitlabSubscriptions
  module DuoEnterpriseAlert
    class BaseComponent < ViewComponent::Base
      # @param [Namespace or Group] namespace
      # @param [User] user

      def initialize(namespace:, user:)
        @namespace = namespace
        @user = user
      end

      private

      attr_reader :namespace, :user

      delegate :sprite_icon, to: :helpers

      def card_options
        {
          class: 'gl-border gl-border-blue-300 gl-bg-blue-50 gl-rounded-base gl-text-left gl-mt-6 gl-p-3',
          data: { testid: 'duo-enterprise-trial-alert' }
        }
      end

      def icon
        sprite_icon('tanuki-ai', css_class: 'gl-mr-2 !gl-align-baseline')
      end

      def title
        s_('BillingPlans|Get the most out of GitLab with Ultimate and GitLab Duo Enterprise')
      end

      def primary_cta_options
        {
          href: primary_link,
          variant: 'confirm',
          button_text_classes: '!gl-whitespace-normal',
          button_options: {
            class: 'gl-w-full sm:gl-w-auto',
            data: {
              event_tracking: 'click_duo_enterprise_trial_billing_page',
              event_label: primary_tracking_label
            }
          }
        }
      end

      def primary_link
        new_trial_path(namespace_id: namespace.id)
      end

      def primary_tracking_label
        'ultimate_and_duo_enterprise_trial'
      end

      def primary_cta
        s_('BillingPlans|Start free trial of GitLab Ultimate and GitLab Duo Enterprise')
      end

      def hand_raise_lead_data
        {
          glm_content: 'billing-group',
          cta_tracking: {
            action: 'hand_raise_form_viewed',
            label: 'click_duo_enterprise_trial_billing_page'
          }.to_json,
          button_attributes: {
            variant: 'confirm',
            category: 'secondary',
            class: 'gl-w-full sm:gl-w-auto'
          }.to_json
        }
      end
    end
  end
end
