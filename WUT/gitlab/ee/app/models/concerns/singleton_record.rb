# frozen_string_literal: true

module SingletonRecord
  extend ActiveSupport::Concern

  included do
    validate :validates_singleton
  end

  class_methods do
    def instance
      # rubocop:disable Performance/ActiveRecordSubtransactionMethods -- only
      # uses a subtransaction if creating a record, which should only happen
      # once per instance
      safe_find_or_create_by(singleton: true) do |setting|
        setting.assign_attributes(defaults)
      end
      # rubocop:enable Performance/ActiveRecordSubtransactionMethods
    end

    def defaults
      {}
    end
  end

  private

  def validates_singleton
    return unless self.class.count > 0 && self != self.class.first

    errors.add(:base, "There can only be one #{self.class.name.demodulize} record")
  end
end
