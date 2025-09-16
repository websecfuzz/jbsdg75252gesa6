# frozen_string_literal: true

module EE
  module API
    module MergeRequestApprovals
      extend ActiveSupport::Concern

      prepended do
        before { authenticate_non_get! }

        helpers do
          # Overrides helper from CE (see https://gitlab.com/gitlab-org/gitlab/-/issues/408183)
          def present_approval(merge_request)
            present merge_request.approval_state, with: ::EE::API::Entities::ApprovalState, current_user: current_user
          end

          def present_merge_request_approval_state(presenter:, target_branch: nil)
            merge_request = find_merge_request_with_access(params[:merge_request_iid])

            present(
              merge_request.approval_state(target_branch: target_branch),
              with: presenter,
              current_user: current_user
            )
          end
        end

        params do
          requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
          requires :merge_request_iid, type: Integer, desc: 'The IID of a merge request'
        end
        resource :projects, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
          segment ':id/merge_requests/:merge_request_iid' do
            desc 'List approval rules for merge request', {
              is_array: true,
              success: ::EE::API::Entities::MergeRequestApprovalSettings,
              hidden: true
            }
            params do
              optional :target_branch, type: String,
                desc: 'Branch that scoped approval rules apply to',
                documentation: { example: 'main' }
            end
            get 'approval_settings' do
              present_merge_request_approval_state(
                presenter: ::EE::API::Entities::MergeRequestApprovalSettings,
                target_branch: declared_params[:target_branch]
              )
            end

            desc 'Get approval state of merge request' do
              success ::EE::API::Entities::MergeRequestApprovalState
            end
            get 'approval_state' do
              present_merge_request_approval_state(presenter: ::EE::API::Entities::MergeRequestApprovalState)
            end

            # Deprecated in favor of approval rules API
            desc 'Deprecated in 16.0: Use the merge request approvals API instead. Change approval-related configuration' do
              detail 'This feature was introduced in 10.6 and deprecated in 16.0'
              success ::EE::API::Entities::ApprovalState
              deprecated true
            end
            params do
              requires :approvals_required, type: Integer,
                desc: 'The amount of approvals required. Must be higher than the project approvals',
                documentation: { example: 2 }
            end
            post 'approvals' do
              merge_request = find_merge_request_with_access(params[:merge_request_iid], :update_merge_request)

              error!('Overriding approvals is disabled', 422) if merge_request.project.disable_overriding_approvers_per_merge_request

              approval_rule = merge_request.approval_rules.any_approver.first

              approval_params = declared_params(include_missing: false)

              result = if approval_rule
                         ::ApprovalRules::UpdateService.new(approval_rule, current_user, approval_params).execute
                       else
                         ::ApprovalRules::CreateService.new(merge_request, current_user, approval_params).execute
                       end

              if result[:status] == :success
                present_approval(merge_request)
              else
                render_api_error!(result.message, result.cause.access_denied? ? 403 : 400)
              end
            end
          end
        end
      end
    end
  end
end
