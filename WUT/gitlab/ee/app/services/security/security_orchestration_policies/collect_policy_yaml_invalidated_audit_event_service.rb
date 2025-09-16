# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class CollectPolicyYamlInvalidatedAuditEventService
      include Gitlab::Utils::StrongMemoize

      def initialize(policy_configuration)
        @policy_configuration = policy_configuration
      end

      def execute
        return if policy_configuration.policy_configuration_valid?

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      private

      attr_reader :policy_configuration

      def audit_context
        {
          name: 'policy_yaml_invalidated',
          author: commit&.author || Gitlab::Audit::DeletedAuthor.new(id: -4, name: 'Unknown User'),
          scope: policy_management_project,
          target: policy_management_project,
          message: 'The policy YAML has been invalidated in the security policy project. ' \
            'Security policies will no longer be enforced.',
          additional_details: {
            security_policy_project_commit_sha: commit&.sha,
            security_orchestration_policy_configuration_id: policy_configuration.id
          }
        }
      end

      def commit
        policy_configuration.latest_commit_before_configured_at
      end

      def policy_management_project
        policy_configuration.security_policy_management_project
      end
      strong_memoize_attr :policy_management_project
    end
  end
end
