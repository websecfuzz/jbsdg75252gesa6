# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::DestroyForGroupService, feature_category: :permissions do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be_with_reload(:member) { create(:group_member, :guest, user: user, group: group) }

  subject(:execute) do
    described_class.new(member.user, member.source).execute
    user.reload
  end

  before do
    create(:user_group_member_role, user: user, group: group)
    create(:user_group_member_role, user: user, group: other_group)
  end

  it 'destroys the UserGroupMemberRole record for the user in the group' do
    expect { execute }.to change {
      [
        user.user_group_member_roles.where(group: group).exists?,
        user.user_group_member_roles.where(group: other_group).exists?
      ]
    }.from([true, true]).to([false, true])
  end

  context 'when there are groups shared with the group' do
    let_it_be(:shared_group) { create(:group) }
    let_it_be(:shared_group2) { create(:group) }
    let_it_be(:shared_group3) { create(:group) }

    before do
      create(:user_group_member_role, user: user, group: shared_group, shared_with_group: group)
      create(:user_group_member_role, user: user, group: shared_group2, shared_with_group: group)
      create(:user_group_member_role, user: user, group: shared_group3, shared_with_group: other_group)
    end

    it 'destroys UserGroupMemberRole records for the user in the group and in all shared groups to the group' do
      expect { execute }.to change {
        [
          user.user_group_member_roles.where(group: group).exists?,
          user.user_group_member_roles.where(group: shared_group).exists?,
          user.user_group_member_roles.where(group: shared_group2).exists?,
          user.user_group_member_roles.where(group: shared_group3).exists?
        ]
      }.from([true, true, true, true]).to([false, false, false, true])
    end
  end
end
