# frozen_string_literal: true

module API
  module Entities
    class ServiceAccount < UserSafe
      expose :email, documentation: { type: 'string', example: 'service_account@example.com' }
      expose :unconfirmed_email, if: ->(service_account) { service_account.unconfirmed_email.present? },
        documentation: { type: 'string', example: 'updated_service_account@example.com' }
    end
  end
end
