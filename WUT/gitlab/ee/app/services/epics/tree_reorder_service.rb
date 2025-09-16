# frozen_string_literal: true

module Epics
  class TreeReorderService < BaseService
    attr_reader :current_user, :moving_object, :params

    def initialize(current_user, moving_object_id, params)
      @current_user = current_user
      @params = params
      @moving_object = find_object(moving_object_id)&.sync
    end

    def execute
      error_message = validate_objects
      return error(error_message) if error_message.present?

      service_response = set_new_parent
      return error(service_response[:message]) if service_response&.fetch(:status) == :error

      move!
      success
    rescue Epics::SyncAsWorkItem::SyncAsWorkItemError => error
      Gitlab::ErrorTracking.track_exception(
        error, moving_object_id: moving_object.id, moving_object_class: moving_object.class.name
      )
      Gitlab::EpicWorkItemSync::Logger.error(error: error)

      error("Couldn't perform re-order due to an internal error.", 422)
    end

    private

    def set_new_parent
      return unless new_parent && new_parent_different?

      service_response = create_issuable_links(new_parent)
      return service_response if service_response[:status] == :error

      # The `moving_object` references might have changed.
      @moving_object = service_response[:created_references].first

      service_response
    end

    def new_parent_different?
      params[:new_parent_id] != GitlabSchema.id_from_object(moving_object.parent)
    end

    def create_issuable_links(parent)
      service, issuable = case moving_object
                          when Epic
                            [::WorkItems::LegacyEpics::EpicLinks::CreateService, moving_object]
                          when EpicIssue
                            [::WorkItems::LegacyEpics::EpicIssues::CreateService, moving_object.issue]
                          end

      return unless service.present?

      service.new(parent, current_user, { target_issuable: issuable }).execute
    end

    def move!
      if adjacent_reference
        moving_object.move_between(before_object, after_object)
      else
        moving_object.move_to_start
      end

      ApplicationRecord.transaction do
        moving_object.save!(touch: false)
        sync_move_to_work_item!
      end
    end

    def before_object
      return unless params[:relative_position] == 'before'

      adjacent_reference
    end

    def after_object
      return unless params[:relative_position] == 'after'

      adjacent_reference
    end

    def validate_objects
      return 'Only epics and epic_issues are supported.' unless supported_types?
      return 'You don\'t have permissions to move the objects.' unless authorized?

      validate_adjacent_reference if adjacent_reference
    end

    def validate_adjacent_reference
      return 'Relative position is not valid.' unless valid_relative_position?

      if different_epic_parent?
        "The sibling object's parent must match the #{new_parent ? 'new' : 'current'} parent epic."
      end
    end

    def supported_types?
      return false if adjacent_reference && !supported_type?(adjacent_reference)

      supported_type?(moving_object)
    end

    def valid_relative_position?
      %w[before after].include?(params[:relative_position])
    end

    def different_epic_parent?
      if new_parent
        new_parent != adjacent_reference.parent
      else
        moving_object.parent != adjacent_reference.parent
      end
    end

    def supported_type?(object)
      object.is_a?(EpicIssue) || object.is_a?(Epic)
    end

    def authorized?
      return false unless can_reorder_object?(moving_object)

      if adjacent_reference
        return false unless can_reorder_adjacent_reference?
      end

      if new_parent
        return false unless can_move_under_new_parent?
      end

      true
    end

    def can_reorder_object?(moving_object)
      return false unless can_admin_epic_relation?(base_epic)

      case moving_object
      when Epic
        can_admin_epic_relation?(moving_object, tree_object: true)
      when EpicIssue
        can_admin_epic_issue?(moving_object)
      end
    end

    def can_reorder_adjacent_reference?
      case adjacent_reference
      when Epic
        can_admin_epic_relation?(adjacent_reference)
      when EpicIssue
        can_admin_epic_issue?(adjacent_reference)
      end
    end

    def can_move_under_new_parent?
      return false unless can_admin_epic_relation?(new_parent, tree_object: true)
      return false unless moving_object.parent && can_admin_epic_relation?(moving_object.parent)

      true
    end

    def can_admin_epic_issue?(epic_issue)
      can?(current_user, :admin_issue_relation, epic_issue.issue) &&
        can_admin_epic_relation?(epic_issue.epic)
    end

    def can_admin_epic_relation?(epic, tree_object: false)
      ability = tree_object ? :admin_epic_tree_relation : :admin_epic_relation

      can?(current_user, ability, epic)
    end

    def base_epic
      @base_epic ||= find_object(params[:base_epic_id])&.sync
    end

    def adjacent_reference
      return unless params[:adjacent_reference_id]

      @adjacent_reference ||= find_object(params[:adjacent_reference_id])&.sync
    end

    def new_parent
      return unless params[:new_parent_id]

      @new_parent ||= find_object(params[:new_parent_id])&.sync
    end

    def find_object(id)
      GitlabSchema.find_by_gid(id)
    end

    def sync_move_to_work_item!
      return if new_parent_has_no_adjacent_item? || not_all_items_have_a_work_item?

      result = WorkItems::ParentLinks::ReorderService.new(work_item_parent, current_user,
        work_item_reorder_params).execute

      raise SyncAsWorkItem::SyncAsWorkItemError, result[:message] if result[:status] == :error
    end

    # No need to sync the relative_position if we move the work item to a new parent without an adjacent reference.
    def new_parent_has_no_adjacent_item?
      new_parent.present? && adjacent_reference.nil?
    end

    # We can't sync the moving object when its parent or adjacent has no synced work item because we can't determine the
    # correct relative position.
    def not_all_items_have_a_work_item?
      adjacent_reference&.work_item.nil? || moving_object.work_item.nil? || work_item_parent.nil?
    end

    def work_item_parent
      @work_item_parent ||= new_parent ? new_parent.work_item : moving_object.work_item&.work_item_parent
    end

    def work_item_reorder_params
      # We changed the API for WorkItems::ParentLinks:
      # 1. The `relative_position` is uppercase
      # 2. The logic of the `relative_position`` is about the work item, instead of the adjacent objet.
      #    e.g. if relative_position is `AFTER` then the work item will be after the given adjacent object. Compared to
      #    the Epics::TreeReorderService where the adjacent object will be placed after the work item.
      {
        adjacent_work_item: adjacent_reference.work_item,
        target_issuable: moving_object.work_item,
        synced_work_item: true,
        relative_position: params[:relative_position] == 'after' ? 'BEFORE' : 'AFTER'
      }
    end
  end
end
