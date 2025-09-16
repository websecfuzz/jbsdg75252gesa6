# frozen_string_literal: true

module ApprovalRules
  module Updater
    include ::AuditEvents::Changes

    APPROVAL_RULE_UPDATE_EVENT_NAME = 'update_approval_rules'
    APPROVAL_RULE_CREATE_EVENT_NAME = 'approval_rule_created'

    def execute
      if group_rule? && Feature.disabled?(:approval_group_rules, rule.group)
        return ServiceResponse.error(message: "The feature approval_group_rules is not enabled.")
      end

      super
    end

    private

    def container
      return rule.group if group_rule?

      rule.project
    end

    def group_rule?
      rule.is_a?(ApprovalGroupRule)
    end

    def action
      filter_eligible_users!
      filter_eligible_groups!
      filter_eligible_protected_branches!

      old_protected_branches_names = nil

      old_protected_branches_names = rule.protected_branches.map(&:name) if rule.is_a? ApprovalProjectRule

      update_rule ? success_with_audit_logging(old_protected_branches_names) : error
    end

    def filter_eligible_users!
      return unless params.key?(:user_ids) || params.key?(:usernames)

      users = User.by_ids_or_usernames(params.delete(:user_ids), params.delete(:usernames))
      if group_container?
        filter_group_members(users)
      else
        filter_project_members(users)
      end
    end

    def filter_project_members(users)
      params[:users] = rule.project.members_among(users)
    end

    def filter_group_members(users)
      users_ids_of_direct_members = rule.group.users_ids_of_direct_members
      params[:users] = users.select { |user| users_ids_of_direct_members.include?(user.id) }
    end

    def filter_eligible_groups!
      return unless params.key?(:group_ids)

      group_ids = params.delete(:group_ids)

      params[:groups] = if params.delete(:permit_inaccessible_groups)
                          Group.id_in(group_ids)
                        else
                          Group.id_in(group_ids).accessible_to_user(current_user)
                        end
    end

    def filter_eligible_protected_branches!
      protected_branch_ids = params.delete(:protected_branch_ids)

      return unless protected_branch_ids && can_create_rule_for_protected_branches?

      params[:protected_branches] = ProtectedBranch.id_in(protected_branch_ids).for_project(project)

      return unless project.root_namespace.is_a?(Group)

      params[:protected_branches] += ProtectedBranch.id_in(protected_branch_ids).for_group(project.root_namespace)
    end

    def update_rule
      return rule.update(params) unless current_user

      audit_context = {
        name: rule.new_record? ? APPROVAL_RULE_CREATE_EVENT_NAME : APPROVAL_RULE_UPDATE_EVENT_NAME,
        author: current_user,
        scope: container,
        target: rule
      }

      ::Gitlab::Audit::Auditor.audit(audit_context) { rule.update(params) }
    end

    def success_with_audit_logging(old_protected_branches_names)
      log_audit_changes(old_protected_branches_names) if current_user

      rule.reset

      success
    end

    def log_audit_changes(old_protected_branches_names)
      audit_changes(
        :approvals_required,
        as: 'number of required approvals',
        entity: container,
        model: rule,
        event_type: APPROVAL_RULE_UPDATE_EVENT_NAME
      )
      audit_changes(:name,
        as: 'name',
        entity: container,
        model: rule,
        event_type: APPROVAL_RULE_UPDATE_EVENT_NAME)

      return unless rule.is_a? ApprovalProjectRule

      audit_message = protected_branch_change_audit_message(rule, old_protected_branches_names)

      return unless audit_message.present?

      ::Gitlab::Audit::Auditor.audit(
        author: current_user,
        name: APPROVAL_RULE_UPDATE_EVENT_NAME,
        scope: container,
        target: rule,
        message: audit_message
      )
    end

    def can_create_rule_for_protected_branches?
      # Currently group approval rules support only all protected branches.
      return false if group_container? || !project.multiple_approval_rules_available?

      skip_authorization || can?(current_user, :admin_project, project)
    end

    def protected_branch_change_audit_message(rule, old_protected_branches_names)
      new_protected_branches_names = rule.protected_branches.map(&:name)
      recently_added_branch = new_protected_branches_names - old_protected_branches_names
      enabled_all_protected_branches = rule.previous_changes["applies_to_all_protected_branches"] == [false, true]
      disabled_all_protected_branches = rule.previous_changes["applies_to_all_protected_branches"] == [true, false]
      from_protected_branch_to_empty = (rule.protected_branches.empty? && old_protected_branches_names.present?)

      if enabled_all_protected_branches
        "Changed target branch to all protected branches"
      elsif disabled_all_protected_branches && new_protected_branches_names.present?
        "Changed target branch to #{new_protected_branches_names.first} branch"
      elsif from_protected_branch_to_empty
        "Changed target branch to all branches"
      elsif recently_added_branch.present?
        "Changed target branch to #{recently_added_branch.first} branch"
      end
    end
  end
end
