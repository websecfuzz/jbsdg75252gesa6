# frozen_string_literal: true

module WorkItems
  module Weights
    class UpdateRolledUpWeightsEventHandler
      include Gitlab::EventStore::Subscriber

      data_consistency :delayed
      feature_category :team_planning
      idempotent!

      UPDATE_TRIGGER_ATTRIBUTES = %w[
        weight
        state_id
      ].freeze

      UPDATE_TRIGGER_WIDGETS = %w[
        weight_widget
        hierarchy_widget
      ].freeze

      def self.can_handle?(event)
        return false unless Feature.enabled?(:update_rolled_up_weights, :instance)

        # For update events, check if weight-related attributes/widgets were updated
        if event.data.key?(:updated_widgets) || event.data.key?(:updated_attributes)
          return UPDATE_TRIGGER_WIDGETS.any? { |widget| event.data.fetch(:updated_widgets, []).include?(widget) } ||
              UPDATE_TRIGGER_ATTRIBUTES.any? { |attr| event.data.fetch(:updated_attributes, []).include?(attr) }
        end

        # For other events (create, delete, close, reopen), check if work item has weight
        work_item_id = event.data[:id]
        return false unless work_item_id

        work_item = WorkItem.find_by_id(work_item_id)
        return false unless work_item

        work_item.weight.present?
      end

      def handle_event(event)
        work_item_id = event.data[:id]
        return unless work_item_id

        work_item_ids = []

        # Add parent IDs from event data if present
        work_item_ids << event.data[:work_item_parent_id] if event.data[:work_item_parent_id]

        work_item_ids << event.data[:previous_work_item_parent_id] if event.data[:previous_work_item_parent_id]

        # If no parent IDs in event data, look up the work item's parent
        if work_item_ids.empty?
          work_item = WorkItem.find_by_id(work_item_id)
          work_item_ids << work_item.work_item_parent.id if work_item&.work_item_parent
        end

        work_item_ids.compact!
        return if work_item_ids.blank?

        UpdateWeightsWorker.perform_async(work_item_ids)
      end
    end
  end
end
