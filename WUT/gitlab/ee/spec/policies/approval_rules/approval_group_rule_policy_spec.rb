# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::ApprovalGroupRulePolicy, feature_category: :source_code_management do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:approval_rule) { create(:approval_group_rule, group: group) }

  def permissions(user, approval_rule)
    described_class.new(user, approval_rule)
  end

  context 'when user can update group' do
    it 'allows updating approval rule' do
      expect(permissions(user, approval_rule)).to be_allowed(:edit_group_approval_rule)
    end
  end

  context 'when user cannot update group' do
    it 'disallows updating approval rule' do
      expect(permissions(create(:user), approval_rule)).to be_disallowed(:edit_group_approval_rule)
    end
  end

  context 'when user can read a group' do
    it 'allows reading an approval rule' do
      expect(permissions(user, approval_rule)).to be_allowed(:read_group_approval_rule)
    end
  end

  context 'when user cannot read a group' do
    it 'disallows reading an approval rule' do
      expect(permissions(create(:user), approval_rule)).to be_disallowed(:read_group_approval_rule)
    end
  end
end
