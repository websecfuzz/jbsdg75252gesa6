# frozen_string_literal: true

module Vulnerabilities
  class Identifier < ::SecApplicationRecord
    include EachBatch
    include ShaAttribute

    self.table_name = "vulnerability_identifiers"

    sha_attribute :fingerprint

    SEARCH_RESULTS_LIMIT = 50

    has_many :finding_identifiers, class_name: 'Vulnerabilities::FindingIdentifier', inverse_of: :identifier, foreign_key: 'identifier_id'
    has_many :findings, through: :finding_identifiers, class_name: 'Vulnerabilities::Finding'

    has_many :primary_findings, class_name: 'Vulnerabilities::Finding', inverse_of: :primary_identifier, foreign_key: 'primary_identifier_id'

    belongs_to :project

    validates :project, presence: true
    validates :external_type, presence: true
    validates :external_id, presence: true
    validates :fingerprint, presence: true
    # Uniqueness validation doesn't work with binary columns, so save this useless query. It is enforce by DB constraint anyway.
    # TODO: find out why it fails
    # validates :fingerprint, presence: true, uniqueness: { scope: :project_id }
    validates :name, presence: true
    validates :url, url: { schemes: %w[http https ftp], allow_nil: true }

    scope :by_projects, ->(values) { where(project_id: values) }
    scope :with_fingerprint, ->(fingerprints) { where(fingerprint: fingerprints) }
    scope :with_external_type, ->(external_type) { where('LOWER(external_type) = LOWER(?)', external_type) }

    def cve?
      external_type.casecmp?('cve')
    end

    def cwe?
      external_type.casecmp?('cwe')
    end

    def other?
      !(cve? || cwe?)
    end

    def self.search_identifier_name(project_id, search_pattern)
      result = where(project_id: project_id)
        .loose_index_scan(column: :name)
        .where("name ILIKE ?", ["%", sanitize_sql_like(search_pattern), "%"].join)
        .order(:name)
        .limit(SEARCH_RESULTS_LIMIT)

      result.map(&:name)
    end

    def self.search_identifier_name_in_group(group, search_pattern)
      project_ids = ::Vulnerabilities::Statistic.by_group(group).unarchived.select(:project_id)
      where(project_id: project_ids)
        .distinct
        .where("name ILIKE ?", ["%", sanitize_sql_like(search_pattern), "%"].join)
        .order(:name)
        .limit(SEARCH_RESULTS_LIMIT)
        .pluck(:name)
    end

    # This is included at the bottom of the model definition because
    # BulkInsertSafe complains about the autosave callbacks generated
    # for the `has_many` associations otherwise.
    include BulkInsertSafe
  end
end
