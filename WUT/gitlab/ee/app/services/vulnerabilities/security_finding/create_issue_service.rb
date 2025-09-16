# frozen_string_literal: true

module Vulnerabilities
  module SecurityFinding
    class CreateIssueService < ::BaseProjectService
      attr_reader :error_message

      def execute
        raise Gitlab::Access::AccessDeniedError unless can?(@current_user, :read_security_resource, @project)

        issue = nil
        @error_message = nil

        vulnerability = create_vulnerability
        issue = create_issue(vulnerability)
        create_vulnerability_issue_link(vulnerability, issue)

        success_response(issue)

      rescue ActiveRecord::Rollback
        vulnerability.destroy if vulnerability.present?
        issue.destroy if issue.present?

        error_response
      end

      private

      def create_vulnerability
        vulnerability_response = Vulnerabilities::FindOrCreateFromSecurityFindingService.new(
          project: @project,
          current_user: @current_user,
          params: params,
          present_on_default_branch: false,
          state: 'detected').execute

        if vulnerability_response.error?
          @error_message = vulnerability_response[:message]
          raise ActiveRecord::Rollback
        end

        vulnerability_response.payload[:vulnerability]
      end

      def create_issue(vulnerability)
        issue_response = Issues::CreateFromVulnerabilityService.new(
          @project,
          @current_user,
          { vulnerability: vulnerability }).execute

        if issue_response[:status] == :error
          @error_message = issue_response[:message]
          raise ActiveRecord::Rollback
        end

        issue_response[:issue]
      end

      def create_vulnerability_issue_link(vulnerability, issue)
        issue_link_response = VulnerabilityIssueLinks::CreateService
          .new(@current_user, vulnerability, issue, link_type: Vulnerabilities::IssueLink.link_types[:created])
          .execute

        if issue_link_response[:status] == :error
          @error_message = issue_link_response[:message]
          raise ActiveRecord::Rollback
        end
      end

      def error_response
        ServiceResponse.error(message: @error_message)
      end

      def success_response(issue)
        ServiceResponse.success(payload: { issue: issue })
      end
    end
  end
end
