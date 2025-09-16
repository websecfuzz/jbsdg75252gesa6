# frozen_string_literal: true

module Gitlab
  module UsageDataCounters
    module EpicActivityUniqueCounter
      # The 'g_project_management' prefix need to be present
      # on epic event names, because they are persisted at the same
      # slot of issue events to allow data aggregation.
      # More information in: https://gitlab.com/gitlab-org/gitlab/-/issues/322405

      EPIC_CREATED = 'g_project_management_epic_created'
      EPIC_DESCRIPTION_CHANGED = 'g_project_management_users_updating_epic_descriptions'
      EPIC_EMOJI_AWARDED = 'g_project_management_users_awarding_epic_emoji'
      EPIC_EMOJI_REMOVED = 'g_project_management_users_removing_epic_emoji'
      EPIC_NOTE_CREATED = 'g_project_management_users_creating_epic_notes'
      EPIC_NOTE_UPDATED = 'g_project_management_users_updating_epic_notes'
      EPIC_NOTE_DESTROYED = 'g_project_management_users_destroying_epic_notes'
      EPIC_TITLE_CHANGED = 'g_project_management_users_updating_epic_titles'
      EPIC_START_DATE_SET_AS_FIXED = 'g_project_management_users_setting_epic_start_date_as_fixed'
      EPIC_START_DATE_SET_AS_INHERITED = 'g_project_management_users_setting_epic_start_date_as_inherited'
      EPIC_DUE_DATE_SET_AS_FIXED = 'g_project_management_users_setting_epic_due_date_as_fixed'
      EPIC_DUE_DATE_SET_AS_INHERITED = 'g_project_management_users_setting_epic_due_date_as_inherited'
      EPIC_FIXED_START_DATE_UPDATED = 'g_project_management_users_updating_fixed_epic_start_date'
      EPIC_FIXED_DUE_DATE_UPDATED = 'g_project_management_users_updating_fixed_epic_due_date'
      EPIC_ISSUE_ADDED = 'g_project_management_epic_issue_added'
      EPIC_ISSUE_REMOVED = 'g_project_management_epic_issue_removed'
      EPIC_ISSUE_MOVED_FROM_PROJECT = 'g_project_management_epic_issue_moved_from_project'
      EPIC_PARENT_UPDATED = 'g_project_management_users_updating_epic_parent'
      EPIC_CLOSED = 'g_project_management_epic_closed'
      EPIC_REOPENED = 'g_project_management_epic_reopened'
      ISSUE_PROMOTED_TO_EPIC = 'g_project_management_issue_promoted_to_epic'
      EPIC_CONFIDENTIAL = 'g_project_management_users_setting_epic_confidential'
      EPIC_VISIBLE = 'g_project_management_users_setting_epic_visible'
      EPIC_LABELS = 'g_project_management_epic_users_changing_labels'
      EPIC_DESTROYED = 'g_project_management_epic_destroyed'
      EPIC_TASK_CHECKED = 'project_management_users_checking_epic_task'
      EPIC_TASK_UNCHECKED = 'project_management_users_unchecking_epic_task'
      EPIC_CROSS_REFERENCED = 'g_project_management_epic_cross_referenced'
      EPIC_RELATED_ADDED = 'g_project_management_epic_related_added'
      EPIC_RELATED_REMOVED = 'g_project_management_epic_related_removed'
      EPIC_BLOCKING_ADDED = 'g_project_management_epic_blocking_added'
      EPIC_BLOCKING_REMOVED = 'g_project_management_epic_blocking_removed'
      EPIC_BLOCKED_ADDED = 'g_project_management_epic_blocked_added'
      EPIC_BLOCKED_REMOVED = 'g_project_management_epic_blocked_removed'

      class << self
        def track_epic_created_action(author:, namespace:)
          track_internal_action(EPIC_CREATED, author, namespace)
        end

        def track_epic_title_changed_action(author:, namespace:)
          track_internal_action(EPIC_TITLE_CHANGED, author, namespace)
        end

        def track_epic_description_changed_action(author:, namespace:)
          track_internal_action(EPIC_DESCRIPTION_CHANGED, author, namespace)
        end

        def track_epic_note_created_action(author:, namespace:)
          track_internal_action(EPIC_NOTE_CREATED, author, namespace)
        end

        def track_epic_note_updated_action(author:, namespace:)
          track_internal_action(EPIC_NOTE_UPDATED, author, namespace)
        end

        def track_epic_note_destroyed_action(author:, namespace:)
          track_internal_action(EPIC_NOTE_DESTROYED, author, namespace)
        end

        def track_epic_emoji_awarded_action(author:, namespace:)
          track_internal_action(EPIC_EMOJI_AWARDED, author, namespace)
        end

        def track_epic_emoji_removed_action(author:, namespace:)
          track_internal_action(EPIC_EMOJI_REMOVED, author, namespace)
        end

        def track_epic_start_date_set_as_fixed_action(author:, namespace:)
          track_internal_action(EPIC_START_DATE_SET_AS_FIXED, author, namespace)
        end

        def track_epic_start_date_set_as_inherited_action(author:, namespace:)
          track_internal_action(EPIC_START_DATE_SET_AS_INHERITED, author, namespace)
        end

        def track_epic_due_date_set_as_fixed_action(author:, namespace:)
          track_internal_action(EPIC_DUE_DATE_SET_AS_FIXED, author, namespace)
        end

        def track_epic_due_date_set_as_inherited_action(author:, namespace:)
          track_internal_action(EPIC_DUE_DATE_SET_AS_INHERITED, author, namespace)
        end

        def track_epic_fixed_start_date_updated_action(author:, namespace:)
          track_internal_action(EPIC_FIXED_START_DATE_UPDATED, author, namespace)
        end

        def track_epic_fixed_due_date_updated_action(author:, namespace:)
          track_internal_action(EPIC_FIXED_DUE_DATE_UPDATED, author, namespace)
        end

        def track_epic_issue_added(author:, namespace:)
          track_internal_action(EPIC_ISSUE_ADDED, author, namespace)
        end

        def track_epic_issue_removed(author:, namespace:)
          track_internal_action(EPIC_ISSUE_REMOVED, author, namespace)
        end

        def track_epic_issue_moved_from_project(author:, namespace:)
          track_internal_action(EPIC_ISSUE_MOVED_FROM_PROJECT, author, namespace)
        end

        def track_epic_parent_updated_action(author:, namespace:)
          track_internal_action(EPIC_PARENT_UPDATED, author, namespace)
        end

        def track_epic_closed_action(author:, namespace:)
          track_internal_action(EPIC_CLOSED, author, namespace)
        end

        def track_epic_reopened_action(author:, namespace:)
          track_internal_action(EPIC_REOPENED, author, namespace)
        end

        def track_issue_promoted_to_epic(author:, namespace:)
          track_internal_action(ISSUE_PROMOTED_TO_EPIC, author, namespace)
        end

        def track_epic_confidential_action(author:, namespace:)
          track_internal_action(EPIC_CONFIDENTIAL, author, namespace)
        end

        def track_epic_visible_action(author:, namespace:)
          track_internal_action(EPIC_VISIBLE, author, namespace)
        end

        def track_epic_labels_changed_action(author:, namespace:)
          track_internal_action(EPIC_LABELS, author, namespace)
        end

        def track_epic_destroyed(author:, namespace:)
          track_internal_action(EPIC_DESTROYED, author, namespace)
        end

        def track_epic_task_checked(author:, namespace:)
          track_internal_action(EPIC_TASK_CHECKED, author, namespace)
        end

        def track_epic_task_unchecked(author:, namespace:)
          track_internal_action(EPIC_TASK_UNCHECKED, author, namespace)
        end

        def track_epic_cross_referenced(author:, namespace:)
          track_internal_action(EPIC_CROSS_REFERENCED, author, namespace)
        end

        def track_linked_epic_with_type_relates_to_added(author:, namespace:)
          track_internal_action(EPIC_RELATED_ADDED, author, namespace)
        end

        def track_linked_epic_with_type_relates_to_removed(author:, namespace:)
          track_internal_action(EPIC_RELATED_REMOVED, author, namespace)
        end

        def track_linked_epic_with_type_blocks_added(author:, namespace:)
          track_internal_action(EPIC_BLOCKING_ADDED, author, namespace)
        end

        def track_linked_epic_with_type_blocks_removed(author:, namespace:)
          track_internal_action(EPIC_BLOCKING_REMOVED, author, namespace)
        end

        def track_linked_epic_with_type_is_blocked_by_added(author:, namespace:)
          track_internal_action(EPIC_BLOCKED_ADDED, author, namespace)
        end

        def track_linked_epic_with_type_is_blocked_by_removed(author:, namespace:)
          track_internal_action(EPIC_BLOCKED_REMOVED, author, namespace)
        end

        private

        def track_internal_action(event_name, author, namespace)
          return unless Feature.enabled?(:track_epics_activity)
          return unless author

          Gitlab::InternalEvents.track_event(
            event_name,
            user: author,
            namespace: namespace
          )
        end
      end
    end
  end
end
