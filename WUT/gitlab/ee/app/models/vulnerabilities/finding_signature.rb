# frozen_string_literal: true

module Vulnerabilities
  class FindingSignature < ::SecApplicationRecord
    include BulkInsertSafe
    include VulnerabilityFindingSignatureHelpers

    self.table_name = 'vulnerability_finding_signatures'

    belongs_to :finding, foreign_key: 'finding_id', inverse_of: :signatures, class_name: 'Vulnerabilities::Finding'
    enum :algorithm_type, VulnerabilityFindingSignatureHelpers::ALGORITHM_TYPES, prefix: :algorithm
    validates :finding, presence: true

    scope :by_project, ->(project) { joins(:finding).where(vulnerability_occurrences: { project_id: project.id }) }
    scope :by_signature_sha, ->(shas) { where(signature_sha: shas) }
    scope :by_finding_id, ->(finding_ids) { where(finding: finding_ids) }
    scope :eager_load_comparison_entities, -> { includes(finding: [:scanner, :primary_identifier]) }

    def signature_hex
      if dedup_by_type_enabled?
        "#{algorithm_type}:#{signature_sha.unpack1('H*')}"
      else
        signature_sha.unpack1("H*")
      end
    end

    def eql?(other)
      other.is_a?(self.class) &&
        other.algorithm_type == algorithm_type &&
        other.signature_sha == signature_sha
    end

    alias_method :==, :eql?

    private

    def dedup_by_type_enabled?
      return false unless finding&.project

      finding.project.licensed_feature_available?(:vulnerability_finding_signatures) && Feature.enabled?(
        :vulnerability_signatures_dedup_by_type, finding.project)
    end
  end
end
