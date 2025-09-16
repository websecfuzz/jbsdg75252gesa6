# frozen_string_literal: true

module Resolvers
  module SecurityOrchestration
    class ScanExecutionPolicyResolver < BaseResolver
      include ResolvesOrchestrationPolicy
      include ConstructScanExecutionPolicies

      type Types::SecurityOrchestration::ScanExecutionPolicyType, null: true

      argument :action_scan_types, [::Types::Security::ReportTypeEnum],
        description: "Filters policies by the action scan type. "\
                   "Only these scan types are supported: #{::Security::ScanExecutionPolicy::SCAN_TYPES.map { |type| "`#{type}`" }.join(', ')}.",
        required: false

      argument :relationship, ::Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum,
        description: 'Filter policies by the given policy relationship. Default is DIRECT.',
        required: false,
        default_value: :direct

      argument :include_unscoped, GraphQL::Types::Boolean,
        description: 'Filter policies that are scoped to the project.',
        required: false,
        default_value: true

      def resolve(**args)
        policies = ::Security::ScanExecutionPoliciesFinder.new(context[:current_user], project, args).execute
        construct_scan_execution_policies(policies)
      end
    end
  end
end
