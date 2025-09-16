# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::DestroyForSharedGroupService, feature_category: :permissions do
  let_it_be(:shared_group) { create(:group) }
  let_it_be(:shared_with_group) { create(:group) }
  let_it_be(:other_shared_group) { create(:group) }

  # Records that should not be deleted by the service
  let_it_be(:other1) do
    create(:user_group_member_role, group: other_shared_group, shared_with_group: shared_with_group)
  end

  let_it_be(:other2) { create(:user_group_member_role, group: shared_group, shared_with_group: other_shared_group) }

  subject(:execute) do
    described_class.new(shared_group, shared_with_group).execute
  end

  before do
    create(:user_group_member_role, group: shared_group, shared_with_group: shared_with_group)
    create(:user_group_member_role, group: shared_group, shared_with_group: shared_with_group)
  end

  it 'destroys UserGroupMemberRole records for the shared_group through shared_with_group' do
    expect { execute }.to change {
      Authz::UserGroupMemberRole.where(group: shared_group, shared_with_group: shared_with_group).count
    }.from(2).to(0)

    expect(Authz::UserGroupMemberRole.where(id: [other1.id, other2.id]).count).to be 2
  end
end
