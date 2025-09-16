# frozen_string_literal: true

module Ai
  module Catalog
    class BaseService < ::BaseContainerService
      DEFAULT_VERSION = 'v1.0.0-draft'

      def initialize(project:, current_user:, params: {})
        super(container: project, current_user: current_user, params: params)
      end

      private

      def allowed?
        current_user.can?(:admin_ai_catalog_item, project)
      end

      def error(message)
        ServiceResponse.error(message: Array(message))
      end

      def error_no_permissions
        error('You have insufficient permissions')
      end
    end
  end
end
