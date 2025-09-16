# frozen_string_literal: true

module WorkItems
  module Statuses
    class Finder
      attr_reader :namespace, :params

      def initialize(namespace, params = {})
        @namespace = namespace
        @params = params
      end

      def execute
        if params.key?('system_defined_status_identifier')
          find_system_defined_status_by_id
        elsif params.key?('custom_status_id')
          find_custom_status_by_id
        elsif params.key?('name')
          find_status_by_name
        end
      end

      private

      def find_system_defined_status_by_id
        ::WorkItems::Statuses::SystemDefined::Status
          .find_by(id: params['system_defined_status_identifier'].to_i) # rubocop: disable CodeReuse/ActiveRecord -- this is a fixed model
      end

      def find_custom_status_by_id
        ::WorkItems::Statuses::Custom::Status
          .in_namespace(namespace)
          .find_by_id(params['custom_status_id'])
      end

      def find_status_by_name
        name = params['name']
        return if name.blank?

        if namespace&.custom_statuses&.exists?
          ::WorkItems::Statuses::Custom::Status.find_by_namespace_and_name(namespace, name)
        else
          ::WorkItems::Statuses::SystemDefined::Status.find_by_name(name)
        end
      end
    end
  end
end
