# frozen_string_literal: true

module EE
  module GroupGroupLink
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include ::MemberRoles::MemberRoleRelation
      include GroupLinksHelper

      base_access_level_attr :group_access
      alias_method :group, :shared_group

      scope :in_shared_group, ->(shared_groups) { where(shared_group: shared_groups) }
      scope :not_in_shared_with_group, ->(shared_with_groups) { where.not(shared_with_group: shared_with_groups) }

      scope :with_custom_role, -> { where.not(member_role_id: nil) }

      validate :group_with_allowed_email_domains
    end

    override :human_access
    def human_access
      return member_role.name if custom_role_for_group_link_enabled?(group) && member_role

      super
    end

    private

    def group_with_allowed_email_domains
      return unless shared_group && shared_with_group

      shared_group_domains = shared_group.root_ancestor_allowed_email_domains.pluck(:domain).to_set
      return if shared_group_domains.empty?

      shared_with_group_domains = shared_with_group.root_ancestor_allowed_email_domains.pluck(:domain).to_set

      if shared_with_group_domains.empty? || !shared_with_group_domains.subset?(shared_group_domains)
        errors.add(:group_id, _("Invited group allowed email domains must contain a subset of the allowed "\
          "email domains of the root ancestor group. Go to the group's 'Settings &gt; General' page "\
          "and check 'Restrict membership by email domain'."))
      end
    end
  end
end
