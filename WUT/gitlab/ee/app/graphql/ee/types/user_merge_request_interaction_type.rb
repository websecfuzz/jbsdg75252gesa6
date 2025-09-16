# frozen_string_literal: true

module EE
  module Types
    module UserMergeRequestInteractionType
      extend ActiveSupport::Concern

      prepended do
        field :applicable_approval_rules,
          [::Types::ApprovalRuleType],
          null: true,
          description: 'Approval rules that apply to the user for the merge request.'
      end
    end
  end
end
