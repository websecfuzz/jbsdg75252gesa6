# frozen_string_literal: true

module EE
  module MergeRequestSidebarBasicEntity
    extend ActiveSupport::Concern

    prepended do
      expose :multiple_approval_rules_available do |merge_request|
        merge_request.target_project.multiple_approval_rules_available?
      end
    end
  end
end
