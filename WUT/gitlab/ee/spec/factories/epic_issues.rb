# frozen_string_literal: true

FactoryBot.define do
  factory :epic_issue, traits: [:with_parent_link] do
    transient do
      epic { nil }
      issue { nil }
    end

    relative_position { RelativePositioning::START_POSITION }

    trait :with_parent_link do
      work_item_parent_link do
        association(
          :parent_link,
          work_item_id: issue&.id || issue_id,
          relative_position: relative_position,
          work_item_parent: epic&.work_item
        )
      end
    end

    after(:build) do |epic_issue, evaluator|
      epic = evaluator.epic
      issue = evaluator.issue

      if epic.present? && issue.nil?
        epic_issue.epic = epic
        epic_issue.issue = create(:issue, project: create(:project, group: epic.group))
      elsif issue.present? && epic.nil?
        unless issue.project.group.present?
          raise 'Failed to create epic_issue. The issue needs to exist under a project with a parent group'
        end

        epic_issue.issue = issue
        epic_issue.epic = create(:epic, group: issue.project.group)
      elsif issue.nil? && epic.nil?
        epic_issue.epic = create(:epic)
        epic_issue.issue = create(:issue, project: create(:project, group: epic_issue.epic.group))
      else
        epic_issue.epic = epic
        epic_issue.issue = issue
      end
    end
  end
end
