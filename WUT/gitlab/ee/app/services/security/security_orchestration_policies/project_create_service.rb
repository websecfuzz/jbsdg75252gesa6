# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class ProjectCreateService < ::BaseContainerService
      ACCESS_LEVELS_TO_ADD = [Gitlab::Access::MAINTAINER, Gitlab::Access::DEVELOPER].freeze
      README_TEMPLATE_PATH = Rails.root.join('ee', 'app', 'views', 'projects', 'security', 'policies', 'readme.md.tt')

      def execute
        return error(s_('User does not have permission to create a Security Policy project.')) unless can_create_projects_in_container?
        return error(s_('Security Policy project already exists.')) if container.security_orchestration_policy_configuration.present?
        return error(s_('Security Policy project already exists, but is not linked.')) if unlinked_project_exists?

        policy_project = ::Projects::CreateService.new(current_user, create_project_params).execute

        return error(policy_project.errors.full_messages.join(',')) unless policy_project.saved?

        if project_container?
          members = add_members(policy_project)
          errors = members.flat_map { |member| member.errors.full_messages }

          return error(s_('Project was created and assigned as security policy project, but failed adding users to the project.')) if errors.any?
        end

        success(policy_project: policy_project)
      end

      private

      delegate :id, :projects, to: :namespace, prefix: true

      def unlinked_project_exists?
        namespace_projects.with_name(create_project_params[:name]).exists?
      end

      def add_members(policy_project)
        members_to_add = developers_and_maintainers_without_group_access(policy_project)
        policy_project.add_members(members_to_add, :developer)
      end

      def developers_and_maintainers_without_group_access(policy_project)
        # rubocop:disable CodeReuse/ActiveRecord -- too specific for a scope
        user_ids = ProjectAuthorization
                     .where(project_id: container.id, access_level: ACCESS_LEVELS_TO_ADD)
                     .where_not_exists(
                       GroupMember
                         .where("members.user_id = project_authorizations.user_id")
                         .where(source_id: policy_project.namespace.self_and_ancestor_ids,
                           access_level: ::Gitlab::Access::DEVELOPER...))
                     .distinct
                     .pluck(:user_id) # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- avoids cross-join
        # rubocop:enable CodeReuse/ActiveRecord

        return User.none if user_ids.none?

        User.id_in(user_ids)
      end

      def create_project_params
        {
          creator: current_user,
          visibility_level: container.visibility_level,
          name: "#{container.name} - Security policy project",
          description: "This project is automatically generated to manage security policies for the project.",
          namespace_id: namespace_id,
          organization_id: namespace.organization_id,
          initialize_with_readme: true,
          container_registry_enabled: false,
          packages_enabled: false,
          requirements_enabled: false,
          builds_enabled: false,
          wiki_enabled: false,
          snippets_enabled: false,
          readme_template: readme_template,
          merge_requests_author_approval: true
        }.merge(security_policy_target_id)
      end

      def security_policy_target_id
        if project_container?
          { security_policy_target_project_id: container.id }
        elsif namespace_container?
          { security_policy_target_namespace_id: container.id }
        end
      end

      def namespace
        return container if namespace_container?

        container.namespace
      end

      def readme_template
        ERB.new(File.read(README_TEMPLATE_PATH), trim_mode: '<>').result(binding)
      end

      def url_helpers
        Rails.application.routes.url_helpers
      end

      def scan_execution_policies_docs_link
        url_helpers.help_page_url('user/application_security/policies/scan_execution_policies.md',
          anchor: 'scan-execution-policy-schema')
      end

      def group_level_branch_protection_docs_link
        url_helpers.help_page_url('user/group/manage.md', anchor: 'change-the-default-branch-protection-of-a-group')
      end

      def instance_level_branch_protection_docs_link
        url_helpers.help_page_url('user/project/repository/branches/default.md',
          anchor: 'for-all-projects-in-an-instance')
      end

      def can_create_projects_in_container?
        current_user.can?(:create_projects, namespace)
      end
    end
  end
end
