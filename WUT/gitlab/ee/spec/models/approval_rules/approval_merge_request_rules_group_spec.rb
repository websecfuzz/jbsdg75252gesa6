# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::ApprovalMergeRequestRulesGroup, feature_category: :source_code_management do
  subject { build(:approval_merge_request_rules_group) }

  describe 'associations' do
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:approval_merge_request_rule) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:approval_merge_request_rule) }
  end
end
