# frozen_string_literal: true

module EE
  module GroupsHelper
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize
    include ::Nav::GitlabDuoSettingsPage

    def size_limit_message_for_group(group)
      repository_size_limit_link = link_to _('Learn more'), help_page_path('administration/settings/account_and_limit_settings.md', anchor: 'repository-size-limit')
      message = group.lfs_enabled? ? _("Max size for repositories within this group, including LFS files. %{repository_size_limit_link}.") : _("Max size for repositories within this group. %{repository_size_limit_link}.")

      safe_format(message, repository_size_limit_link: repository_size_limit_link)
    end

    override :subgroup_creation_data
    def subgroup_creation_data(group)
      super.merge({
        identity_verification_required: current_user.requires_identity_verification_to_create_group?(group).to_s,
        identity_verification_path: identity_verification_path
      })
    end

    def show_discover_group_security?(group)
      !!current_user &&
        ::Gitlab.com? &&
        !group.licensed_feature_available?(:security_dashboard) &&
        can?(current_user, :admin_group, group)
    end

    def show_group_activity_analytics?
      can?(current_user, :read_group_activity_analytics, @group)
    end

    def show_product_purchase_success_alert?
      !params[:purchased_product].blank?
    end

    def show_user_cap_alert?
      root_namespace = @group.root_ancestor

      return false unless root_namespace.present? &&
        can?(current_user, :admin_group, root_namespace) &&
        root_namespace.user_cap_available? &&
        root_namespace.namespace_settings.present?

      root_namespace.user_cap_enabled?
    end

    def pending_members_link
      link_to('', pending_members_group_usage_quotas_path(@group.root_ancestor))
    end

    def group_seats_usage_quota_app_data(group)
      {
        namespace_id: group.id,
        namespace_name: group.name,
        is_public_namespace: group.public?.to_s,
        full_path: group.full_path,
        seat_usage_export_path: group_seat_usage_path(group, format: :csv),
        subscription_history_href: subscription_history_group_usage_quotas_path(group),
        add_seats_href: add_seats_url(group),
        max_free_namespace_seats: ::Namespaces::FreeUserCap.dashboard_limit,
        explore_plans_path: group_billings_path(group),
        enforcement_free_user_cap_enabled: ::Namespaces::FreeUserCap::Enforcement.new(group).enforce_cap?.to_s
      }
    end

    def duo_home_app_data(group)
      settings = group.namespace_settings

      {
        duo_seat_utilization_path: group_settings_gitlab_duo_seat_utilization_index_path(group),
        duo_availability: settings.duo_availability.to_s,
        experiment_features_enabled: settings.experiment_features_enabled.to_s,
        prompt_cache_enabled: group.namespace_settings.model_prompt_cache_enabled.to_s,
        are_experiment_settings_allowed: group.experiment_settings_allowed?.to_s,
        are_prompt_cache_settings_allowed: group.prompt_cache_settings_allowed?.to_s,
        duo_configuration_path: group_settings_gitlab_duo_configuration_index_path(group),
        are_duo_core_features_enabled: settings.duo_core_features_enabled.to_s,
        model_switching_enabled: can?(current_user, :admin_group_model_selection, group).to_s,
        model_switching_path: group_settings_gitlab_duo_model_selection_index_path(group)
      }.merge(code_suggestions_usage_app_data(group))
    end

    def code_suggestions_usage_app_data(group)
      {
        full_path: group.full_path,
        group_id: group.id,
        add_duo_pro_href: duo_pro_url(group),
        duo_pro_bulk_user_assignment_available: 'true',
        hand_raise_lead: code_suggestions_usage_app_hand_raise_lead_data,
        is_free_namespace: group.has_free_or_no_subscription?.to_s,
        buy_subscription_path: group_billings_path(group),
        duo_page_path: group_settings_gitlab_duo_path(group)
      }.merge(duo_pro_trial_link(group), active_duo_add_on_data(group), active_subscription_data(group))
    end

    def active_subscription_data(group)
      return {} unless group_gitlab_subscription(group)

      {
        subscription_start_date: group_gitlab_subscription(group).start_date,
        subscription_end_date: group_gitlab_subscription(group).end_date
      }
    end

    def group_gitlab_subscription(group)
      strong_memoize(:group_gitlab_subscription) do
        group.gitlab_subscription
      end
    end

    def active_duo_add_on_data(group)
      active_duo_add_on = group.subscription_add_on_purchases.for_duo_pro_or_duo_enterprise.active.first

      return {} unless active_duo_add_on

      duo_add_on_end_date = if active_duo_add_on.trial?
                              active_duo_add_on.expires_on
                            else
                              # When the purchase is not a trial, we add the 14-day grace
                              # period to expires_on. For displaying purposes, we subtract
                              # the grace period to show the correct end date.
                              active_duo_add_on.expires_on - SUBSCRIPTION_GRACE_PERIOD
                            end

      {
        duo_add_on_is_trial: active_duo_add_on.trial?.to_s,
        duo_add_on_start_date: active_duo_add_on.started_at,
        duo_add_on_end_date: duo_add_on_end_date
      }
    end

    def product_analytics_usage_quota_app_data(group)
      {
        namespace_path: group.full_path,
        empty_state_illustration_path: image_path('illustrations/empty-state/empty-dashboard-md.svg'),
        product_analytics_enabled: ::Gitlab::CurrentSettings.product_analytics_enabled?.to_s
      }
    end

    def show_usage_quotas_tab?(group, tab)
      case tab
      when :seats
        License.feature_available?(:seat_usage_quotas)
      when :code_suggestions
        show_gitlab_duo_settings_app?(group)
      when :pipelines
        Ability.allowed?(current_user, :admin_ci_minutes, group) &&
          License.feature_available?(:pipelines_usage_quotas)
      when :transfer
        ::Feature.enabled?(:data_transfer_monitoring, group) &&
          License.feature_available?(:transfer_usage_quotas)
      when :product_analytics
        License.feature_available?(:product_analytics_usage_quotas)
      when :pages
        group.root_ancestor == group && License.feature_available?(:pages_multiple_versions)
      else
        false
      end
    end

    def saml_sso_settings_generate_helper_text(display_none:, text:)
      content_tag(:span, text, class: ['js-helper-text', 'gl-clearfix', ('gl-hidden' if display_none)])
    end

    def group_transfer_app_data(group)
      {
        full_path: group.full_path
      }
    end

    def pages_deployments_app_data(group)
      limit = group.actual_limits.active_versioned_pages_deployments_limit_by_namespace
      count_by_project = ::PagesDeployment.count_versioned_deployments_for(
        group.all_projects.with_namespace_domain_pages,
        limit,
        group_by_project: true
      )

      {
        full_path: group.full_path,
        deployments_count: count_by_project.values.sum,
        deployments_limit: limit,
        # rubocop: disable CodeReuse/ActiveRecord -- Limited re-usability for this pluck
        deployments_by_project: group.all_projects.with_namespace_domain_pages.pluck(:id, :name).map do |id, name|
          {
            name: name,
            count: count_by_project[id]
          }
        end.to_json
        # rubocop: enable CodeReuse/ActiveRecord
      }
    end

    private

    SUBSCRIPTION_GRACE_PERIOD = 14.days
    private_constant :SUBSCRIPTION_GRACE_PERIOD

    def duo_pro_trial_link(group)
      if GitlabSubscriptions::DuoPro.no_add_on_purchase_for_namespace?(group) &&
          GitlabSubscriptions::DuoPro.namespace_eligible?(group)
        return { duo_pro_trial_href: new_trials_duo_pro_path(namespace_id: group.id) }
      end

      {}
    end
  end
end
