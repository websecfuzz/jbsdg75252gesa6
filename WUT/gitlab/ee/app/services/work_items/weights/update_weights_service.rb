# frozen_string_literal: true

module WorkItems
  module Weights
    class UpdateWeightsService
      def initialize(work_items)
        @work_items = Array.wrap(work_items)
      end

      def execute
        return unless Feature.enabled?(:update_rolled_up_weights, :instance)

        ::ApplicationRecord.transaction do
          process_work_items_with_ancestors
        end
      end

      private

      attr_reader :work_items

      def process_work_items_with_ancestors
        work_items.each do |work_item|
          WorkItems::WeightsSource.upsert_rolled_up_weights_for(work_item)

          work_item.ancestors.each do |ancestor|
            WorkItems::WeightsSource.upsert_rolled_up_weights_for(ancestor)
          end
        end
      end
    end
  end
end
