# frozen_string_literal: true

module EE
  module WorkItemsHelper
    extend ::Gitlab::Utils::Override

    override :work_items_data
    def work_items_data(resource_parent, current_user)
      group = resource_parent.is_a?(Group) ? resource_parent : resource_parent.group

      super.merge(
        has_blocked_issues_feature: resource_parent.licensed_feature_available?(:blocked_issues).to_s,
        has_issue_weights_feature: resource_parent.licensed_feature_available?(:issue_weights).to_s,
        has_okrs_feature: resource_parent.licensed_feature_available?(:okrs).to_s,
        has_epics_feature: resource_parent.licensed_feature_available?(:epics).to_s,
        has_group_bulk_edit_feature: resource_parent.licensed_feature_available?(:group_bulk_edit).to_s,
        has_iterations_feature: resource_parent.licensed_feature_available?(:iterations).to_s,
        has_issuable_health_status_feature: resource_parent.licensed_feature_available?(:issuable_health_status).to_s,
        has_subepics_feature: resource_parent.licensed_feature_available?(:subepics).to_s,
        has_scoped_labels_feature: resource_parent.licensed_feature_available?(:scoped_labels).to_s,
        has_quality_management_feature: resource_parent.licensed_feature_available?(:quality_management).to_s,
        can_bulk_edit_epics: can?(current_user, :bulk_admin_epic, resource_parent).to_s,
        new_comment_template_paths: new_comment_template_paths(
          group,
          resource_parent.is_a?(Group) ? nil : resource_parent
        ).to_json,
        group_issues_path: issues_group_path(resource_parent),
        labels_fetch_path: group_labels_path(
          resource_parent, format: :json, only_group_labels: true, include_ancestor_groups: true),
        epics_list_path: group_epics_path(resource_parent),
        has_linked_items_epics_feature: resource_parent.licensed_feature_available?(:linked_items_epics).to_s,
        has_status_feature: resource_parent.licensed_feature_available?(:work_item_status).to_s,
        has_custom_fields_feature: resource_parent.licensed_feature_available?(:custom_fields).to_s
      )
    end

    override :add_work_item_show_breadcrumb
    def add_work_item_show_breadcrumb(resource_parent, iid)
      if resource_parent.work_items.with_work_item_type.find_by_iid(iid)&.group_epic_work_item?
        return add_to_breadcrumbs(_('Epics'), group_epics_path(resource_parent))
      end

      super
    end
  end
end
