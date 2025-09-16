# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class CollectPoliciesAuditEvents
      include BaseServiceUtility
      include Gitlab::Utils::StrongMemoize

      def initialize(policy_configuration:, created_policies: [], updated_policies: [], deleted_policies: [])
        @policy_configuration = policy_configuration
        @created_policies = created_policies
        @updated_policies = updated_policies
        @deleted_policies = deleted_policies
      end

      def execute
        bulk_audit_policies(created_policies, 'security_policy_create', 'Created')
        bulk_audit_policies(updated_policies, 'security_policy_update', 'Updated')
        bulk_audit_policies(deleted_policies, 'security_policy_delete', 'Deleted')
      end

      private

      attr_reader :created_policies, :updated_policies, :deleted_policies, :policy_configuration

      def commit
        policy_configuration.latest_commit_before_configured_at
      end

      def policy_management_project
        policy_configuration.security_policy_management_project
      end
      strong_memoize_attr :policy_management_project

      def bulk_audit_policies(policies, event_name, action)
        policies.each do |policy|
          audit_context = build_audit_context(policy, event_name, action)

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end
      end

      def build_audit_context(policy, event_name, action)
        {
          name: event_name,
          author: commit&.author || Gitlab::Audit::DeletedAuthor.new(id: -3, name: 'Unknown User'),
          scope: policy_management_project,
          target: policy,
          target_details: policy.name,
          message: audit_message(policy, action),
          created_at: Time.current,
          additional_details: {
            policy_name: policy.name,
            event_name: event_name,
            policy_type: policy.type,
            security_policy_project_commit_sha: commit&.sha,
            security_policy_project_id: policy_management_project.id,
            policy_configured_at: policy_configuration.configured_at
          }
        }
      end

      def audit_message(policy, action)
        "#{action} security policy with the name: \"#{policy.name}\""
      end
    end
  end
end
