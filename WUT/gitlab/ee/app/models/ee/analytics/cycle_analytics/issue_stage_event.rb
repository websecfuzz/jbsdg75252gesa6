# frozen_string_literal: true

module EE
  module Analytics
    module CycleAnalytics
      module IssueStageEvent
        extend ActiveSupport::Concern

        prepended do
          has_one :epic_issue, primary_key: 'issue_id', foreign_key: 'issue_id' # rubocop: disable Rails/InverseOf

          scope :without_weight, ->(weight) { where(weight: nil).or(where.not(weight: weight)) }
          scope :without_sprint_id, ->(sprint_id) { where(sprint_id: nil).or(where.not(sprint_id: sprint_id)) }
          scope :without_epic_id, ->(epic_id) do
            left_joins(:epic_issue)
              .merge(EpicIssue.where(epic_id: nil).or(EpicIssue.where.not(epic_id: epic_id)))
          end
        end
      end
    end
  end
end
