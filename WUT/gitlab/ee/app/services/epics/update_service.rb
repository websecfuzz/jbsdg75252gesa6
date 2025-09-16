# frozen_string_literal: true

module Epics
  class UpdateService < Epics::BaseService
    include Gitlab::Utils::StrongMemoize
    include SyncAsWorkItem

    EPIC_DATE_FIELDS = %I[
      start_date_fixed
      start_date_is_fixed
      due_date_fixed
      due_date_is_fixed
    ].freeze

    attr_reader :epic_board_id

    def execute(epic)
      # start_date and end_date columns are no longer writable by users because those
      # are composite fields managed by the system.
      params.extract!(:start_date, :end_date)

      update_task_event(epic) || update(epic)

      if saved_change_to_epic_dates?(epic)
        Epics::UpdateDatesService.new([epic]).execute

        track_start_date_fixed_events(epic)
        track_due_date_fixed_events(epic)
        track_fixed_dates_updated_events(epic)

        epic.reset
      end

      track_changes(epic)

      assign_parent_epic_for(epic)
      remove_parent_epic_for(epic)
      assign_child_epic_for(epic)

      epic
    end

    override :handle_changes
    def handle_changes(epic, options)
      super

      old_associations = options.fetch(:old_associations, {})
      old_mentioned_users = old_associations.fetch(:mentioned_users, [])

      todo_service.update_epic(epic, current_user, old_mentioned_users)

      if epic.saved_change_to_attribute?(:confidential)
        handle_confidentiality_change(epic)
      end
    end

    override :associations_before_update
    def associations_before_update(epic)
      associations = super

      associations[:parent] = epic.parent

      associations
    end

    def handle_label_changes(epic, old_labels)
      return false unless super

      todo_service.resolve_todos_for_target(epic, current_user)
    end

    def handle_confidentiality_change(epic)
      if epic.confidential?
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_confidential_action(
          author: current_user,
          namespace: epic.group
        )
        # don't enqueue immediately to prevent todos removal in case of a mistake
        ::TodosDestroyer::ConfidentialEpicWorker.perform_in(::Todo::WAIT_FOR_DELETE, epic.id)
      else
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_visible_action(
          author: current_user,
          namespace: epic.group
        )
      end
    end

    def handle_task_changes(epic)
      todo_service.resolve_todos_for_target(epic, current_user)
      todo_service.update_epic(epic, current_user)
    end

    private

    def transaction_update(epic, opts = {})
      super.tap do |save_result|
        break save_result unless save_result

        update_work_item_for!(epic)
      end
    end

    override :transaction_update_task
    def transaction_update_task(epic)
      super.tap do |save_result|
        break save_result unless save_result

        update_work_item_for!(epic)
      end
    end

    def after_update(epic, _old_associations)
      super

      epic.run_after_commit_or_now do
        # trigger this event after all actions related to saving an epic are done, after commit is not late enough,
        # because after update epic transaction is commited, there are still things happening related to epic, e.g.
        # some associations are updated/linked to the newly updated epic, etc.
        ::Gitlab::EventStore.publish(::Epics::EpicUpdatedEvent.new(data: { id: epic.id, group_id: epic.group_id }))
      end
    end

    def track_fixed_dates_updated_events(epic)
      fixed_start_date_updated = epic.saved_change_to_attribute?(:start_date_fixed)
      fixed_due_date_updated = epic.saved_change_to_attribute?(:due_date_fixed)
      return unless fixed_start_date_updated || fixed_due_date_updated

      if fixed_start_date_updated
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_fixed_start_date_updated_action(
          author: current_user,
          namespace: epic.group
        )
      end

      if fixed_due_date_updated
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_fixed_due_date_updated_action(
          author: current_user,
          namespace: epic.group
        )
      end
    end

    def track_start_date_fixed_events(epic)
      return unless epic.saved_change_to_attribute?(:start_date_is_fixed)

      if epic.start_date_is_fixed?
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_start_date_set_as_fixed_action(
          author: current_user,
          namespace: epic.group
        )
      else
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_start_date_set_as_inherited_action(
          author: current_user,
          namespace: epic.group
        )
      end
    end

    def track_due_date_fixed_events(epic)
      return unless epic.saved_change_to_attribute?(:due_date_is_fixed)

      if epic.due_date_is_fixed?
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_due_date_set_as_fixed_action(
          author: current_user,
          namespace: epic.group
        )
      else
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_due_date_set_as_inherited_action(
          author: current_user,
          namespace: epic.group
        )
      end
    end

    def issuable_for_positioning(id, positioning_scope)
      return unless id

      positioning_scope.find_by_epic_id(id)
    end

    def saved_change_to_epic_dates?(epic)
      (epic.saved_changes.keys.map(&:to_sym) & EPIC_DATE_FIELDS).present?
    end

    def track_changes(epic)
      if epic.saved_change_to_attribute?(:title)
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_title_changed_action(author: current_user, namespace: epic.group)
      end

      if epic.saved_change_to_attribute?(:description)
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_description_changed_action(author: current_user, namespace: epic.group)
        track_task_changes(epic)
      end
    end

    def track_task_changes(epic)
      return if epic.updated_tasks.blank?

      epic.updated_tasks.each do |task|
        if task.complete?
          Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_task_checked(
            author: current_user,
            namespace: epic.group
          )
        else
          Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_task_unchecked(
            author: current_user,
            namespace: epic.group
          )
        end
      end
    end
  end
end
