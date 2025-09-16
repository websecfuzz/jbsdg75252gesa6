# frozen_string_literal: true

module Vulnerabilities
  class StateTransition < ::SecApplicationRecord
    include EachBatch
    include BulkInsertSafe

    self.table_name = 'vulnerability_state_transitions'

    belongs_to :author, class_name: 'User', inverse_of: :vulnerability_state_transitions
    belongs_to :vulnerability, class_name: 'Vulnerability', inverse_of: :state_transitions
    validates :comment, length: { maximum: 50_000 }
    validates :vulnerability_id, :from_state, :to_state, presence: true
    validate :to_state_and_from_state_differ

    enum :from_state, ::Enums::Vulnerability.vulnerability_states, prefix: true
    enum :to_state, ::Enums::Vulnerability.vulnerability_states, prefix: true

    declarative_enum DismissalReasonEnum

    scope :by_to_states, ->(states) { where(to_state: states) }
    scope :by_vulnerability, ->(values) { where(vulnerability_id: values) }

    private

    def to_state_and_from_state_differ
      return if to_state&.to_sym == :dismissed

      errors.add(:to_state, "must not be the same as from_state") if to_state == from_state
    end
  end
end
