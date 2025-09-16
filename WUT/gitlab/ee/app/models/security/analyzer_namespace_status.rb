# frozen_string_literal: true

module Security
  class AnalyzerNamespaceStatus < ::SecApplicationRecord
    include EachBatch
    include ::Namespaces::Traversal::Traversable

    self.table_name = 'analyzer_namespace_statuses'

    belongs_to :group, foreign_key: :namespace_id, inverse_of: :analyzer_group_statuses
    belongs_to :namespace

    enum :analyzer_type, Enums::Security.extended_analyzer_types

    validates :success, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :failure, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :analyzer_type, presence: true
    validates :traversal_ids, presence: true

    scope :by_namespace, ->(namespace) { where(namespace_id: namespace) }

    def total_projects_count
      @total_projects_count ||= group.all_unarchived_project_ids.size
    end

    def not_configured
      [total_projects_count - success - failure, 0].max
    end
  end
end
