# frozen_string_literal: true

module Ci
  module Sources
    class Project < Ci::ApplicationRecord
      include Ci::NamespacedModelName
      include Ci::Partitionable

      self.table_name = "ci_sources_projects"

      belongs_to :pipeline, class_name: "Ci::Pipeline", optional: false
      belongs_to :source_project, class_name: "::Project", foreign_key: :source_project_id, optional: false

      validates :pipeline_id, uniqueness: { scope: :source_project_id }

      partitionable scope: :pipeline
    end
  end
end
