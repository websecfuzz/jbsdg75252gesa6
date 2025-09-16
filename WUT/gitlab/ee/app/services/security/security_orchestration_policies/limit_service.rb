# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class LimitService < BaseContainerService
      DEFAULT_LIMITS = {
        pipeline_execution_policies: {
          configuration: 5,
          pipeline: 5
        }
      }.freeze

      def pipeline_execution_policies_per_configuration_limit
        root_namespace_pipeline_execution_policies_per_configuration_limit.presence ||
          Gitlab::CurrentSettings.pipeline_execution_policies_per_configuration_limit.presence ||
          DEFAULT_LIMITS.dig(:pipeline_execution_policies, :configuration)
      end

      def pipeline_execution_policies_per_pipeline_limit
        DEFAULT_LIMITS.dig(:pipeline_execution_policies, :pipeline)
      end

      private

      attr_reader :container

      def root_namespace_pipeline_execution_policies_per_configuration_limit
        limit = container&.root_ancestor&.pipeline_execution_policies_per_configuration_limit
        return if limit&.zero?

        limit
      end
    end
  end
end
