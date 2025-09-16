# frozen_string_literal: true

# Security::ScanResultPolicies::FindingsFinder
#
# This finder returns `Security::Finding` for a given pipeline
# and a list of given pipeline ids with conditions matching the rules
# configured in scan result policies.
#
# Arguments:
#   pipeline - pipeline for which the findings should be returned
#   params:
#     scanners:             Array<String>
#     severity_levels:      Array<String>
#     check_dismissed:      Boolean
#     vulnerability_states: Array<String>
#     related_pipeline_ids: Array<Integer>
#     false_positive:       Boolean
#     fix_available:        Boolean
module Security
  module ScanResultPolicies
    class FindingsFinder
      def initialize(project, pipeline, params = {})
        @project = project
        @pipeline = pipeline
        @params = params
      end

      attr_reader :project, :pipeline, :params

      def execute
        findings = security_findings

        findings = findings.by_severity_levels(params[:severity_levels]) if params[:severity_levels].present?
        findings = findings.by_report_types(params[:scanners]) if params[:scanners].present?
        findings = undismissed_security_findings(findings) if only_new_undismissed_findings?
        findings = findings.by_state(:dismissed) if only_new_dismissed_findings?
        findings = findings.false_positives if params[:false_positive] == true
        findings = findings.non_false_positives if params[:false_positive] == false
        findings = findings.fix_available if params[:fix_available] == true
        findings = findings.no_fix_available if params[:fix_available] == false
        findings = findings.with_scan_partition_number.by_uuid(params[:uuids]) if params[:uuids].present?

        findings
      end

      private

      def security_findings
        return Security::Finding.none unless pipeline

        findings = if params[:related_pipeline_ids].present?
                     Security::Finding.by_project_id_and_pipeline_ids(project.id, params[:related_pipeline_ids])
                   else
                     pipeline.security_findings.by_partition_number(pipeline.security_findings_partition_number)
                   end

        findings.merge(::Security::Scan.latest_successful)
      end

      def only_new_dismissed_findings?
        params[:check_dismissed] &&
          params[:vulnerability_states].include?(ApprovalProjectRule::NEW_DISMISSED) &&
          params[:vulnerability_states].exclude?(ApprovalProjectRule::NEW_NEEDS_TRIAGE)
      end

      def only_new_undismissed_findings?
        params[:check_dismissed] &&
          params[:vulnerability_states].exclude?(ApprovalProjectRule::NEW_DISMISSED) &&
          params[:vulnerability_states].include?(ApprovalProjectRule::NEW_NEEDS_TRIAGE)
      end

      def undismissed_security_findings(findings)
        findings.undismissed_by_vulnerability
      end
    end
  end
end
