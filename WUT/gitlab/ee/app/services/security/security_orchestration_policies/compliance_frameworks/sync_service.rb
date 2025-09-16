# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module ComplianceFrameworks
      class SyncService
        include Gitlab::Utils::StrongMemoize

        def initialize(security_policy:, policy_diff:)
          @security_policy = security_policy
          @policy_diff = policy_diff
        end

        def execute
          return if policy_diff.present? && !policy_diff.scope_changed?

          framework_ids = security_policy.framework_ids_from_scope
          frameworks_count = linked_compliance_frameworks(framework_ids).count

          if frameworks_count != framework_ids.count
            container = configuration.source

            Gitlab::AppJsonLogger.info(
              message: 'inaccessible compliance_framework_ids found in policy',
              security_policy_id: security_policy.id,
              configuration_id: configuration.id,
              configuration_source_id: container.id,
              root_namespace_ids: linked_source_root_namespaces.map(&:id),
              policy_framework_ids: framework_ids,
              inaccessible_framework_ids_count: (framework_ids.count - frameworks_count)
            )

            return
          end

          framework_policy_attrs = framework_ids.map do |framework_id|
            {
              framework_id: framework_id,
              policy_configuration_id: configuration.id,
              security_policy_id: security_policy.id,
              policy_index: security_policy.policy_index
            }
          end

          ComplianceManagement::ComplianceFramework::SecurityPolicy.relink(security_policy, framework_policy_attrs)
        end

        private

        attr_reader :security_policy, :policy_diff

        def configuration
          security_policy.security_orchestration_policy_configuration
        end
        strong_memoize_attr :configuration

        def linked_compliance_frameworks(framework_ids)
          ComplianceManagement::Framework
            .with_namespaces(linked_source_root_namespaces)
            .id_in(framework_ids)
        end

        def linked_source_root_namespaces
          Security::OrchestrationPolicyConfiguration
            .for_management_project(configuration.security_policy_management_project_id)
            .with_project_and_namespace
            .filter_map { |linked_configuration| linked_configuration.source&.root_ancestor }
            .uniq
        end
        strong_memoize_attr :linked_source_root_namespaces
      end
    end
  end
end
