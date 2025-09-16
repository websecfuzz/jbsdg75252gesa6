# frozen_string_literal: true

module Search
  module Elastic
    class ReindexingTask < ApplicationRecord
      include EachBatch

      HUMAN_STATES = {
        "initial" => { message: "starting", color: "tip" },
        "indexing_paused" => { message: "in progress", color: "info" },
        "reindexing" => { message: "reindexing", color: "info" },
        "success" => { message: "successfully indexed", color: "success" },
        "failure" => { message: "indexing failed", color: "danger" },
        "original_index_deleted" => { message: "original index deleted", color: "info" }
      }.freeze

      self.table_name = 'elastic_reindexing_tasks'

      validates :max_slices_running, presence: true
      validates :slice_multiplier, presence: true
      validates :options, json_schema: { filename: 'elastic_reindexing_task_options' }

      attribute :options, ::Gitlab::Database::Type::IndifferentJsonb.new # for indifferent access

      has_many :subtasks, class_name: 'Search::Elastic::ReindexingSubtask',
        foreign_key: :elastic_reindexing_task_id, inverse_of: :elastic_reindexing_task

      enum :state, {
        initial: 0,
        indexing_paused: 1,
        reindexing: 2,
        success: 10, # states less than 10 are considered in_progress
        failure: 11,
        original_index_deleted: 12
      }

      scope :old_indices_scheduled_for_deletion, -> do
        where(state: %i[success failure]).where.not(delete_original_index_at: nil)
      end
      scope :old_indices_to_be_deleted, -> do
        old_indices_scheduled_for_deletion.where('delete_original_index_at < NOW()')
      end

      before_save :set_in_progress_flag

      def self.current
        where(in_progress: true).last
      end

      def self.running?
        current.present?
      end

      def self.drop_old_indices!
        old_indices_to_be_deleted.find_each do |task|
          task.subtasks.each do |subtask|
            Gitlab::Elastic::Helper.default.delete_index(index_name: subtask.index_name_from)
          end
          task.update!(state: :original_index_deleted)
        end
      end

      def target_classes
        return ::Gitlab::Elastic::Helper::INDEXED_CLASSES if targets.blank?

        targets.map(&:constantize)
      end

      private

      def set_in_progress_flag
        in_progress_states = self.class.states.select { |_, v| v < 10 }.keys

        self.in_progress = in_progress_states.include?(state)
      end
    end
  end
end
