# frozen_string_literal: true

module EE
  module Types
    module MergeRequestType
      extend ActiveSupport::Concern

      prepended do
        field :approvals_left, GraphQL::Types::Int,
          null: true, calls_gitaly: true,
          description: 'Number of approvals left.'

        field :approvals_required, GraphQL::Types::Int,
          calls_gitaly: true,
          null: true, description: 'Number of approvals required.'

        field :merge_train_car, ::Types::MergeTrains::CarType,
          null: true,
          experiment: { milestone: '17.2' },
          description: 'Represents the merge request in a merge train.'

        field :merge_trains_count, GraphQL::Types::Int,
          null: true,
          deprecated: {
            reason: 'Use `count` from `cars` connection on `MergeTrains::TrainType` instead',
            milestone: '17.4'
          },
          description: 'Number of merge requests in the merge train.'

        field :merge_train_index, GraphQL::Types::Int,
          null: true,
          deprecated: {
            reason: 'Use `index` on `MergeTrains::CarType` instead',
            milestone: '17.4'
          },
          description: 'Zero-based position of the merge request in the merge train. ' \
            'Returns `null` if the merge request is not in a merge train.'

        field :has_security_reports, GraphQL::Types::Boolean,
          null: false, calls_gitaly: true,
          method: :has_security_reports?,
          description: 'Indicates if the source branch has any security reports.'

        field :security_reports_up_to_date_on_target_branch, GraphQL::Types::Boolean,
          null: false, calls_gitaly: true,
          method: :security_reports_up_to_date?,
          description: 'Indicates if the target branch security reports are out of date.'

        field :approval_state, ::Types::MergeRequests::ApprovalStateType,
          null: false,
          description: 'Information relating to rules that must be satisfied to merge the merge request.'

        field :policies_overriding_approval_settings,
          type: [::Types::SecurityOrchestration::PolicyApprovalSettingsOverrideType],
          null: true,
          description: 'Approval settings that are overridden by the policies for the merge request.',
          resolver: ::Resolvers::SecurityOrchestration::PolicyApprovalSettingsOverrideResolver

        field :suggested_reviewers, ::Types::AppliedMl::SuggestedReviewersType,
          null: true,
          description: 'Suggested reviewers for merge request.'

        field :blocking_merge_requests, ::Types::MergeRequests::BlockingMergeRequestsType,
          null: true,
          experiment: { milestone: '16.5' },
          description: 'Merge requests that block another merge request from merging.',
          resolver_method: :base_merge_request # processing is done in the GraphQL type

        field :merge_request_diffs, ::Types::MergeRequestDiffType.connection_type,
          null: true,
          experiment: { milestone: '16.2' },
          description: 'Diff versions of a merge request.'

        field :finding_reports_comparer,
          type: ::Types::Security::FindingReportsComparerType,
          null: true,
          experiment: { milestone: '16.1' },
          description: 'Vulnerability finding reports comparison reported on the merge request.',
          resolver: ::Resolvers::SecurityReport::FindingReportsComparerResolver

        field :policy_violations,
          type: ::Types::SecurityOrchestration::PolicyViolationDetailsType,
          null: true,
          description: 'Policy violations reported on the merge request. ',
          resolver: ::Resolvers::SecurityOrchestration::PolicyViolationsResolver

        field :change_requesters,
          type: ::Types::UserType.connection_type,
          null: true,
          description: 'Users that have requested changes to the merge request.'
      end

      def change_requesters
        return unless object.reviewer_requests_changes_feature

        object.change_requesters
      end

      def merge_train_car
        return unless merge_trains_enabled

        object.merge_train_car
      end

      # TODO: remove when field fully deprecated https://gitlab.com/groups/gitlab-org/-/epics/14560
      def merge_trains_count
        return unless merge_trains_enabled

        object.merge_train.car_count
      end

      # TODO: remove when field fully deprecated https://gitlab.com/groups/gitlab-org/-/epics/14560
      def merge_train_index
        return unless merge_trains_enabled

        object.merge_train_car&.index
      end

      def suggested_reviewers
        return unless object.project.can_suggest_reviewers?

        object.predictions
      end

      def base_merge_request
        object
      end

      def mergeable
        lazy_committers { object.mergeable? }
      end

      def detailed_merge_status
        lazy_committers { super }
      end

      private

      def lazy_committers
        # No need to batch load committers and lazy load if we allow committers
        # to approve since we're not going to filter committers so we can return
        # early.
        return yield unless object.merge_requests_disable_committers_approval?

        object.commits.add_committers_to_batch_loader(with_merge_commits: true)
        ::Gitlab::Graphql::Lazy.new do
          yield
        end
      end

      def merge_trains_enabled
        @merge_trains_enabled ||= object.target_project.merge_trains_enabled?
      end
    end
  end
end
