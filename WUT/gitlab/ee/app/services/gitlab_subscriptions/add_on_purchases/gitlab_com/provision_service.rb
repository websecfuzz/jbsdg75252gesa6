# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module GitlabCom
      class ProvisionService
        extend ::Gitlab::Utils::Override

        DUO_CORE = :duo_core
        DUO_PRO = :duo_pro
        DUO_ENTERPRISE = :duo_enterprise
        ADD_ON_MAPPING = { duo_pro: :code_suggestions }.freeze

        attr_accessor :add_on_products, :namespace

        def initialize(namespace, add_on_products = [])
          @namespace = namespace
          @add_on_products = add_on_products
        end

        def execute
          responses = consolidate(add_on_products.deep_symbolize_keys).map do |name, products|
            create_or_update(name, products.first)
          end

          if responses.any?(&:success?)
            GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker.perform_async(namespace.id)
          end

          if responses.all?(&:success?)
            ServiceResponse.success(**service_response(responses))
          else
            ServiceResponse.error(**service_response(responses))
          end
        end

        private

        def consolidate(add_on_products)
          add_on_products.each_with_object({}) do |(key, value), hash|
            value&.map!(&:compact)

            next unless value&.any?(&:present?)
            next if key == DUO_PRO && duo_enterprise_provisionable?

            hash[key] = value
          end
        end

        def duo_enterprise_provisionable?
          add_on_products[DUO_ENTERPRISE]&.first&.dig(:quantity).to_i > 0
        end

        def create_or_update(name, product)
          add_on_purchase = add_on_purchase(name)
          return success unless executable?(add_on_purchase, product, name)

          enable_duo_core_for_new_subscription(name, product)

          attributes = attributes(product).merge(add_on_purchase: add_on_purchase)
          service_class(add_on_purchase).new(namespace, add_on(name), attributes).execute
        end

        def enable_duo_core_for_new_subscription(name, product)
          # respect customer's previous decision on this namespace
          return unless namespace.namespace_settings.duo_core_features_enabled.nil?

          return unless duo_core_from_new_subscription?(name, product)

          namespace.namespace_settings.update!(duo_core_features_enabled: true)
        end

        def duo_core_from_new_subscription?(name, product)
          name == DUO_CORE && product[:new_subscription]
        end

        def executable?(add_on_purchase, product, name)
          create?(add_on_purchase, product) ||
            update?(add_on_purchase, product) ||
            deprovision?(add_on_purchase, product, name)
        end

        def create?(add_on_purchase, product)
          !add_on_purchase && product[:quantity].to_i > 0
        end

        def update?(add_on_purchase, product)
          add_on_purchase && product[:quantity].to_i > 0
        end

        def deprovision?(add_on_purchase, product, name)
          add_on_purchase && product[:quantity].to_i < 1 && add_on_remains_unchanged?(add_on_purchase, name)
        end

        def add_on_remains_unchanged?(add_on_purchase, name)
          add_on_purchase.add_on.name.to_sym == mapped_name(name)
        end

        def attributes(product)
          {
            quantity: product[:quantity],
            started_on: product[:started_on],
            expires_on: product[:expires_on],
            purchase_xid: product[:purchase_xid],
            trial: product[:trial]
          }.compact
        end

        def add_on(name)
          GitlabSubscriptions::AddOn.find_or_create_by_name(mapped_name(name))
        end

        def add_on_purchase(name)
          if name == DUO_PRO || name == DUO_ENTERPRISE
            GitlabSubscriptions::Duo.enterprise_or_pro_for_namespace(namespace.id)
          else
            GitlabSubscriptions::AddOnPurchase.by_namespace(namespace).by_add_on_name(name).first
          end
        end

        def service_response(responses)
          {
            message: responses.filter_map(&:message).join(" ").presence,
            payload: { add_on_purchases: responses.filter_map(&:payload).filter_map(&:values).flatten }
          }
        end

        def service_class(add_on_purchase)
          if add_on_purchase
            GitlabSubscriptions::AddOnPurchases::GitlabCom::UpdateService
          else
            GitlabSubscriptions::AddOnPurchases::CreateService
          end
        end

        def success
          ServiceResponse.success(message: "Nothing to provision or de-provision")
        end

        def mapped_name(name)
          ADD_ON_MAPPING[name] || name
        end
      end
    end
  end
end
