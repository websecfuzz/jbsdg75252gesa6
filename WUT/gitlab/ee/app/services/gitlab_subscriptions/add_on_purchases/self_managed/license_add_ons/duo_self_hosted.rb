# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module LicenseAddOns
        class DuoSelfHosted < Base
          private

          override :name
          def name
            :duo_self_hosted
          end
        end
      end
    end
  end
end
