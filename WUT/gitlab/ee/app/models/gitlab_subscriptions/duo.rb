# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    def self.todo_message
      s_('Todos|You now have access to AI-native features. Learn how to set up Code Suggestions and Chat in your IDE')
    end

    def self.enterprise_or_pro_for_namespace(namespace)
      # If both add-on types are present, prioritize Enterprise over Pro. This is for cases where, for example,
      # a namespace has purchased a Duo Pro add-on but simultaneously has a Duo Enterprise add-on trial.
      duo_enterprise_add_on_purchase = GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(
        namespace,
        add_on: :duo_enterprise,
        only_active: false
      ).execute.first

      duo_enterprise_add_on_purchase || GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(
        namespace,
        add_on: :duo_pro,
        only_active: false
      ).execute.first
    end

    def self.duo_settings_available?(namespace)
      GitlabSubscriptions::AddOnPurchase
        .for_active_add_ons(%i[duo_core code_suggestions duo_enterprise], namespace)
        .exists?
    end

    def self.no_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, add_on: :duo, only_active: false).execute.none?
    end

    def self.any_active_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(namespace, add_on: :duo).execute.any?
    end

    def self.any_add_on_purchase_for_namespace(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, add_on: :duo, only_active: false).execute.first
    end

    def self.active_self_managed_duo_core_pro_or_enterprise?
      GitlabSubscriptions::AddOnPurchase.for_self_managed.for_duo_core_pro_or_enterprise.active.any?
    end

    def self.active_self_managed_duo_pro_or_enterprise
      GitlabSubscriptions::AddOnPurchase.for_self_managed.for_duo_pro_or_duo_enterprise.active.first
    end
  end
end
