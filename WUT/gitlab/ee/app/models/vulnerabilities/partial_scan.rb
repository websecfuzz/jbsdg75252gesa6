# frozen_string_literal: true

module Vulnerabilities
  class PartialScan < SecApplicationRecord
    self.table_name = 'vulnerability_partial_scans'

    enum :mode, {
      differential: 1
    }

    belongs_to :project
    belongs_to :scan, class_name: 'Security::Scan'

    validates :mode, presence: true
    validates :project, presence: true

    before_validation :set_project_id

    def set_project_id
      self.project_id = scan.project_id if project_id.blank?
    end
  end
end
