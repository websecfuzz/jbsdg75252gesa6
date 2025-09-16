# frozen_string_literal: true

class GeoNodeNamespaceLink < ApplicationRecord
  belongs_to :geo_node, inverse_of: :namespaces
  belongs_to :namespace

  validates :namespace_id, presence: true, uniqueness: { scope: [:geo_node_id] }
end
