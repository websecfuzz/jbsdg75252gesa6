# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      class ExpireService
        def initialize(add_on_purchase)
          @add_on_purchase = add_on_purchase
        end

        def execute
          if add_on_purchase.expired? || add_on_purchase.update(expires_on: Date.yesterday)
            ServiceResponse.success(payload: { add_on_purchase: nil })
          else
            ServiceResponse.error(
              message: "#{add_on_purchase.errors.full_messages.to_sentence}.",
              payload: { add_on_purchase: add_on_purchase }
            )
          end
        end

        private

        attr_reader :add_on_purchase
      end
    end
  end
end
