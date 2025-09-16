# frozen_string_literal: true

module WorkItems
  class Progress < ApplicationRecord
    self.table_name = 'work_item_progresses'

    validates :progress, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
    validates :start_value, :current_value, :end_value, :reminder_frequency, presence: true
    validate :check_start_end_values_to_not_be_same

    belongs_to :work_item, foreign_key: 'issue_id', inverse_of: :progress

    after_commit :update_all_parent_objectives_progress

    enum :reminder_frequency, {
      weekly: 1,
      twice_monthly: 2,
      monthly: 3,
      never: 0
    }

    def compute_progress
      return 0 if start_value === end_value

      if start_value < end_value
        return 0 if current_value < start_value
        return 100 if current_value > end_value
      end

      if start_value > end_value
        return 0 if current_value > start_value
        return 100 if current_value < end_value
      end

      # .to_d is not working as expected on linux instances
      # Example: ((94-0)/(100-0) * 100).to_i is returning 93 on linux and 94 on Mac
      # As a solution, I want to replace .to_i to .round
      (((current_value - start_value).abs / (end_value - start_value).abs) * 100).round
    end

    private

    def update_all_parent_objectives_progress
      return unless rollups_enabled?
      return unless saved_change_to_attribute?(:progress)

      ::WorkItems::UpdateParentObjectivesProgressWorker.perform_async(work_item.id)
    end

    def check_start_end_values_to_not_be_same
      errors.add(:start_value, "cannot be same as end value") if start_value == end_value
    end

    def rollups_enabled?
      work_item.project.okr_automatic_rollups_enabled? &&
        rollup_progress?
    end
  end
end
