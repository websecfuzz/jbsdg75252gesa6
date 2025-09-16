# frozen_string_literal: true

module EE
  module IssuablesHelper
    extend ::Gitlab::Utils::Override

    override :issuable_sidebar_options
    def issuable_sidebar_options(sidebar_data, project)
      super.merge(
        weightOptions: ::Issue.weight_options,
        weightNoneValue: ::Issue::WEIGHT_NONE,
        multipleApprovalRulesAvailable: sidebar_data[:multiple_approval_rules_available]
      )
    end

    override :issuable_initial_data
    def issuable_initial_data(issuable)
      data = super.merge(
        canAdmin: can?(current_user, :"admin_#{issuable.to_ability_name}", issuable),
        hasIssueWeightsFeature: issuable.project&.licensed_feature_available?(:issue_weights),
        hasIterationsFeature: issuable.project&.licensed_feature_available?(:iterations),
        canAdminRelation: can?(current_user, :"admin_#{issuable.to_ability_name}_relation", issuable)
      )

      if parent.is_a?(Group)
        data[:confidential] = issuable.confidential
        data[:epicLinksEndpoint] = group_epic_links_path(parent, issuable)
        data[:epicsWebUrl] = group_epics_path(parent)
        data[:fullPath] = parent.full_path
        data[:issueLinksEndpoint] = group_epic_issues_path(parent, issuable)
        data[:issuesWebUrl] = issues_group_path(parent)
        data[:projectsEndpoint] = expose_path(api_v4_groups_projects_path(id: parent.id))
        data[:canReadRelation] = can?(current_user, :read_epic_relation, issuable)
      end

      data
    end

    override :new_comment_template_paths
    def new_comment_template_paths(group, project = nil)
      template_paths = super(group, project)

      if project && can?(current_user, :create_saved_replies, project)
        template_paths << {
          text: _('Project comment templates'),
          href: ::Gitlab::Routing.url_helpers.project_comment_templates_path(project)
        }
      end

      if group && can?(current_user, :create_saved_replies, group)
        template_paths << {
          text: _('Group comment templates'),
          href: ::Gitlab::Routing.url_helpers.group_comment_templates_path(group)
        }
      end

      template_paths
    end

    private

    override :issue_only_initial_data
    def issue_only_initial_data(issuable)
      return {} unless issuable.is_a?(Issue)

      super.merge(
        publishedIncidentUrl: ::Gitlab::StatusPage::Storage.details_url(issuable),
        slaFeatureAvailable: issuable.sla_available?.to_s,
        uploadMetricsFeatureAvailable: issuable.metric_images_available?.to_s,
        projectId: issuable.project_id
      )
    end

    override :issue_header_data
    def issue_header_data(issuable)
      super.tap do |data|
        if issuable.promoted? && can?(current_user, :read_epic, issuable.promoted_to_epic)
          data[:promotedToEpicUrl] =
            url_for([issuable.promoted_to_epic.group, issuable.promoted_to_epic, { only_path: false }])
        end
      end
    end
  end
end
