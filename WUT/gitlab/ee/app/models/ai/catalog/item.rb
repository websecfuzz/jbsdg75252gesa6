# frozen_string_literal: true

module Ai
  module Catalog
    class Item < ApplicationRecord
      self.table_name = "ai_catalog_items"

      validates :organization, :item_type, :description, :name, presence: true

      validates :name, length: { maximum: 255 }
      validates :description, length: { maximum: 1_024 }

      validates_inclusion_of :public, in: [true, false]

      belongs_to :organization, class_name: 'Organizations::Organization', optional: false
      belongs_to :project

      has_many :versions, class_name: 'Ai::Catalog::ItemVersion', foreign_key: :ai_catalog_item_id, inverse_of: :item
      has_one :latest_version, -> { order(id: :desc) }, class_name: 'Ai::Catalog::ItemVersion',
        foreign_key: :ai_catalog_item_id, inverse_of: :item
      has_many :consumers, class_name: 'Ai::Catalog::ItemConsumer', foreign_key: :ai_catalog_item_id, inverse_of: :item

      scope :not_deleted, -> { where(deleted_at: nil) }
      scope :with_item_type, ->(item_type) { where(item_type: item_type) }

      AGENT_TYPE = :agent
      FLOW_TYPE = :flow

      enum :item_type, {
        AGENT_TYPE => 1,
        FLOW_TYPE => 2
      }

      def deleted?
        deleted_at.present?
      end
    end
  end
end
