# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PipelineSkippedAuditor
      include Gitlab::Utils::StrongMemoize

      def initialize(pipeline:)
        @pipeline = pipeline
      end

      def audit
        return unless pipeline
        return unless security_orchestration_policy_configurations.present?
        return unless skipped_policies.present?

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      private

      attr_reader :pipeline

      def audit_context
        {
          name: 'policy_pipeline_skipped',
          author: pipeline.user,
          scope: project,
          target: pipeline,
          target_details: pipeline.commit.present? ? pipeline.commit.title : pipeline.name,
          message: "Pipeline: #{pipeline.id} with security policy jobs skipped",
          additional_details: additional_details
        }
      end

      def additional_details
        {
          commit_sha: pipeline.sha,
          merge_request_title: merge_request&.title,
          merge_request_id: merge_request&.id,
          merge_request_iid: merge_request&.iid,
          source_branch: merge_request&.source_branch,
          target_branch: merge_request&.target_branch,
          project_id: project.id,
          project_name: project.name,
          project_full_path: project.full_path,
          skipped_policies: skipped_policies
        }.compact
      end

      def skipped_policies
        pipeline_execution_policies, scan_execution_policies = active_execution_policies

        skipped_seps = format_skipped_policies(scan_execution_policies, 'scan_execution_policy')
        skipped_peps = format_skipped_policies(pipeline_execution_policies, 'pipeline_execution_policy')

        skipped_seps + skipped_peps
      end

      def format_skipped_policies(policies, type)
        policies.map { |name| { name: name, policy_type: type } }
      end

      def active_execution_policies
        scan_execution_policies = Set.new
        pipeline_execution_policies = Set.new

        security_orchestration_policy_configurations.each do |policy|
          if target_branch_ref
            active_seps_for_policy = policy.active_scan_execution_policy_names(target_branch_ref, project)
          end

          active_peps_for_policy = policy.active_pipeline_execution_policy_names

          scan_execution_policies.merge(active_seps_for_policy) if active_seps_for_policy.present?
          pipeline_execution_policies.merge(active_peps_for_policy) if active_peps_for_policy.present?
        end

        [pipeline_execution_policies, scan_execution_policies]
      end

      strong_memoize_attr :skipped_policies

      def security_orchestration_policy_configurations
        project.all_security_orchestration_policy_configurations
      end
      strong_memoize_attr :security_orchestration_policy_configurations

      def project
        pipeline.project
      end
      strong_memoize_attr :project

      def merge_request
        pipeline.merge_request
      end
      strong_memoize_attr :merge_request

      def target_branch_ref
        merge_request&.target_branch_ref
      end
      strong_memoize_attr :target_branch_ref
    end
  end
end
