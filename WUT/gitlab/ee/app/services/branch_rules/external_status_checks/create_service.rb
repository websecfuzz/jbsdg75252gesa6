# frozen_string_literal: true

module BranchRules
  module ExternalStatusChecks
    class CreateService < BaseService
      private

      def action_name
        'create'
      end

      def execute_on_branch_rule
        create_external_status_check(params.merge(protected_branch_ids: [branch_rule.id]))
      end

      def execute_on_all_branches_rule
        create_external_status_check(params)
      end

      def create_external_status_check(esc_params)
        ::ExternalStatusChecks::CreateService.new(
          container: project,
          current_user: current_user,
          params: esc_params
        ).execute(skip_authorization: true)
      end

      def permitted_params
        %i[name external_url shared_secret]
      end
    end
  end
end
