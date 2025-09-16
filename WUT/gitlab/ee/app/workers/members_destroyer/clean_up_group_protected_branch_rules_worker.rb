# frozen_string_literal: true

module MembersDestroyer
  class CleanUpGroupProtectedBranchRulesWorker
    include ApplicationWorker

    data_consistency :always
    feature_category :groups_and_projects
    idempotent!

    attr_reader :group, :user

    def perform(group_id, user_id)
      @group = ::Group.find_by_id(group_id)
      @user = ::User.find_by_id(user_id)

      return if user.nil? || group.nil?

      destroy_protected_branches_access
    end

    def destroy_protected_branches_access
      merge_access_level_exists = ::ProtectedBranch::MergeAccessLevel.by_user(user).exists?
      push_access_level_exists = ::ProtectedBranch::PushAccessLevel.by_user(user).exists?

      # check if user has any access levels assigned to him to avoid the loop
      return unless merge_access_level_exists || push_access_level_exists

      Project.for_group_and_its_subgroups(group).find_each do |project|
        next if project.member?(user)

        protected_branch_ids = project.protected_branches.select(:id)
        next if protected_branch_ids.empty?

        if merge_access_level_exists
          ::ProtectedBranch::MergeAccessLevel.by_user(user)
                                             .where(protected_branch_id: protected_branch_ids) # rubocop: disable CodeReuse/ActiveRecord
                                             .delete_all
        end

        if push_access_level_exists
          ::ProtectedBranch::PushAccessLevel.by_user(user)
                                            .where(protected_branch_id: protected_branch_ids) # rubocop: disable CodeReuse/ActiveRecord
                                            .delete_all
        end
      end
    end
  end
end
