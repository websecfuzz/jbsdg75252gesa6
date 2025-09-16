# frozen_string_literal: true

module Clusters
  module Agents
    class ManagedResource < ApplicationRecord
      self.table_name = 'clusters_managed_resources'

      belongs_to :build, class_name: 'Ci::Build'
      belongs_to :cluster_agent, class_name: 'Clusters::Agent'
      belongs_to :project
      belongs_to :environment

      validates :template_name, length: { maximum: 1024 }
      validates :tracked_objects, json_schema: { filename: 'clusters_agents_managed_resource_tracked_objects' }

      scope :order_id_desc, -> { order(id: :desc) }

      enum :status, {
        processing: 0,
        completed: 1,
        failed: 2,
        deleting: 3,
        deleted: 4,
        delete_failed: 5
      }

      enum :deletion_strategy, {
        never: 0,
        on_stop: 1,
        on_delete: 2
      }, prefix: true
    end
  end
end
