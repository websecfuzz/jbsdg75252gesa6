# frozen_string_literal: true

module LicenseHelper
  include ActionView::Helpers::AssetTagHelper

  delegate :general_admin_application_settings_path, to: 'Gitlab::Routing.url_helpers'

  def seats_calculation_message(license)
    return unless license.exclude_guests_from_active_count?

    s_("Users with a Guest role or those who don't belong to a Project or Group will not use a seat from your license.")
  end

  def current_license_title
    License.current&.plan&.titleize || s_('BillingPlans|Free')
  end

  def has_active_license?
    License.current.present?
  end

  # EE:Self Managed
  def self_managed_new_trial_url
    subscription_portal_new_trial_url(
      return_to: CGI.escape(Gitlab.config.gitlab.url),
      id: Base64.strict_encode64(current_user.email)
    )
  end

  def show_promotions?(selected_user = current_user, hide_on_self_managed: false)
    return false unless selected_user

    if Gitlab::CurrentSettings.current_application_settings
      .should_check_namespace_plan? # that checks Gitlab.com? too
      true
    elsif hide_on_self_managed
      false
    else
      license = License.current
      license.nil? || license.expired?
    end
  end

  def show_advanced_search_promotion?
    !Gitlab::CurrentSettings.should_check_namespace_plan? && show_promotions? && show_callout?('promote_advanced_search_dismissed') && !License.feature_available?(:elastic_search)
  end

  def licensed_users(license)
    if license.restricted?(:active_user_count)
      number_with_delimiter(license.restrictions[:active_user_count])
    else
      _('Unlimited')
    end
  end

  # EE:Self Managed
  def cloud_license_view_data
    {
      buy_subscription_path: Gitlab::Saas.about_pricing_url,
      customers_portal_url: subscription_portal_manage_url,
      free_trial_path: self_managed_new_trial_url,
      has_active_license: (has_active_license? ? 'true' : 'false'),
      license_remove_path: (current_user.can?(:destroy_licenses) ? admin_license_path : ''),
      subscription_sync_path: sync_seat_link_admin_license_path,
      congratulation_svg_path: image_path('illustrations/cloud-check-sm.svg'),
      license_usage_file_path: admin_license_usage_export_path(format: :csv)
    }
  end

  extend self
end

LicenseHelper.prepend_mod
