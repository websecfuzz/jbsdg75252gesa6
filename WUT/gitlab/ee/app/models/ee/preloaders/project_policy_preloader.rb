# frozen_string_literal: true

module EE
  module Preloaders
    module ProjectPolicyPreloader
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        return if projects.is_a?(ActiveRecord::Relation) && projects.null_relation?

        super

        ActiveRecord::Associations::Preloader.new(records: projects, associations: [:group, :invited_groups]).call
        ::Namespaces::Preloaders::ProjectRootAncestorPreloader.new(projects, :group, root_ancestor_preloads).execute

        if ::Feature.enabled?(:preload_member_roles, current_user)
          ::Preloaders::UserMemberRolesInProjectsPreloader.new(projects: projects, user: current_user).execute
        end

        # Manually preloads saml_providers, which cannot be done in AR, since the
        # relationship is on the root ancestor.
        # This is required since the `:read_group` ability depends on `Group.saml_provider`
        projects.select(&:group).each do |project|
          project.group.root_saml_provider = project.root_ancestor.saml_provider
        end
      end

      private

      def root_ancestor_preloads
        [:ip_restrictions, :saml_provider]
      end
    end
  end
end
