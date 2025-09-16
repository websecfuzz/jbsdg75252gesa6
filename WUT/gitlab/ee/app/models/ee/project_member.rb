# frozen_string_literal: true

module EE
  module ProjectMember
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      extend ::Gitlab::Utils::Override

      validate :sso_enforcement, if: -> { group && user }
      validate :gma_enforcement, if: -> { group && user }
      validate :group_domain_limitations, if: -> { group && group_has_domain_limitations? }, on: :create
      validate :validate_only_one_security_policy_bot_per_source, on: :create

      before_destroy :delete_member_branch_protection
      before_destroy :delete_protected_environment_acceses
    end

    def validate_only_one_security_policy_bot_per_source
      return unless user&.security_policy_bot?
      return unless source.security_policy_bot

      errors.add(:member_user_type, _("Only one security policy bot is allowed per project"))
    end

    def group
      source&.group
    end

    def project_bot
      user&.project_bot?
    end

    def delete_member_branch_protection
      return if group&.member?(user)

      if user.present? && project.present?
        project.protected_branches.merge_access_by_user(user).destroy_all # rubocop: disable Cop/DestroyAll
        project.protected_branches.push_access_by_user(user).destroy_all # rubocop: disable Cop/DestroyAll
      end
    end

    def delete_protected_environment_acceses
      return unless user.present? && project.present?

      project.protected_environments.revoke_user(user)
    end

    def gma_enforcement
      unless ::Gitlab::Auth::GroupSaml::GmaMembershipEnforcer.new(project).can_add_user?(user)
        errors.add(:user, _('is not in the group enforcing Group Managed Account'))
      end
    end

    def provisioned_by_this_group?
      false
    end

    def enterprise_user_of_this_group?
      false
    end

    def group_saml_identity(root_ancestor: false)
      return unless group

      super
    end

    def accept_invite!(new_user)
      return false if source.membership_locked?

      super
    end
  end
end
