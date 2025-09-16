# frozen_string_literal: true

module EE
  module MergeRequestPolicy
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      with_scope :subject
      condition(:can_override_approvers, score: 0) do
        @subject.target_project&.can_override_approvers?
      end

      condition(:external_status_checks_enabled) do
        @subject.target_project&.licensed_feature_available?(:external_status_checks)
      end

      condition(:read_only, scope: :subject) { read_only? }
      condition(:merge_request_discussion_locked) { @subject.discussion_locked? }
      condition(:merge_request_project_archived) { @subject.project.archived? }

      condition(:merge_request_group_approver, score: 140) do
        project = @subject.target_project
        protected_branch = project
          .protected_branches
          .find { |pb| pb.matches?(@subject.target_branch) }

        protected_branch.present? && group_access?(protected_branch)
      end

      condition(:approval_rules_licence_enabled, scope: :subject) do
        @subject.target_project.licensed_feature_available?(:coverage_check_approval_rule) ||
          @subject.target_project.licensed_feature_available?(:report_approver_rules)
      end

      condition(:role_enables_admin_merge_request) do
        ::Authz::CustomAbility.allowed?(@user, :admin_merge_request, subject&.project)
      end

      condition(:target_project_developer) do
        can?(:developer_access, @subject.target_project)
      end

      condition(:target_project_reporter) do
        can?(:reporter_access, @subject.target_project)
      end

      condition(:target_project_internal) do
        @subject.target_project&.internal?
      end

      condition(:user_allowed_to_read_target_project_merge_requests) do
        can?(:read_merge_request, @subject.target_project)
      end

      with_scope :subject
      condition(:custom_roles_allowed) do
        subject&.project&.custom_roles_enabled?
      end

      condition(:generate_commit_message_enabled) do
        subject.project.project_setting.duo_features_enabled?
      end

      condition(:user_allowed_to_use_generate_commit_message) do
        @user.allowed_to_use?(:generate_commit_message, licensed_feature: :generate_commit_message)
      end

      condition(:summarize_review_enabled) do
        subject.project.project_setting.duo_features_enabled? &&
          ::Feature.enabled?(:summarize_my_code_review, @user) &&
          ::Gitlab::Llm::FeatureAuthorizer.new(
            container: @subject.project,
            feature_name: :summarize_review,
            user: @user,
            licensed_feature: :summarize_review
          ).allowed?
      end

      def read_only?
        @subject.target_project&.namespace&.read_only?
      end

      def group_access?(protected_branch)
        protected_branch.approval_project_rules.for_groups(@user.group_members.reporters.select(:source_id)).exists?
      end

      rule { ~can_override_approvers }.prevent :update_approvers

      rule { can?(:update_merge_request) }.policy do
        enable :update_approvers
      end

      rule { merge_request_group_approver }.policy do
        enable :approve_merge_request
      end

      rule { external_status_checks_enabled & target_project_reporter }.policy do
        enable :read_external_status_check_response
      end

      rule do
        external_status_checks_enabled &
          target_project_internal &
          ~external_user &
          user_allowed_to_read_target_project_merge_requests
      end.enable :read_external_status_check_response

      rule { external_status_checks_enabled & target_project_developer }.policy do
        enable :provide_status_check_response
        enable :retry_failed_status_checks
      end

      rule { read_only }.policy do
        prevent :update_merge_request
      end

      rule { approval_rules_licence_enabled }.enable :create_merge_request_approval_rules

      rule { custom_roles_allowed & role_enables_admin_merge_request }.policy do
        enable :approve_merge_request
      end

      rule do
        generate_commit_message_enabled &
          user_allowed_to_use_generate_commit_message
      end.enable :access_generate_commit_message

      rule do
        summarize_review_enabled & can?(:read_merge_request)
      end.enable :access_summarize_review
    end

    private

    override :can_approve?
    def can_approve?
      return can?(:developer_access) if read_only?

      super
    end
  end
end
