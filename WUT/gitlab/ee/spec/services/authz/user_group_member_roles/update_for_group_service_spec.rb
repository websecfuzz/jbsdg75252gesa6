# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::UpdateForGroupService, feature_category: :permissions do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:role) { create(:member_role, :guest, namespace: group) }

  # Set access_level to GUEST (< group_group_link.group_access i.e. DEVELOPER)
  # so we can assert created/updated user_group_member_role.member_role == member.role
  let_it_be_with_reload(:member) { create(:group_member, :guest, member_role: role, user: user, group: group) }

  subject(:execute) do
    described_class.new(member).execute
    user.reload
  end

  before do
    stub_licensed_features(custom_roles: true)
  end

  def create_record(user, group, member_role, shared_with_group: nil)
    attrs = { user: user, group: group, member_role: member_role, shared_with_group: shared_with_group }.compact
    create(:user_group_member_role, attrs)
  end

  def create_group_group_link(group, shared_with_group)
    # Set group_access to DEVELOPER (> member.access_level i.e. GUEST) so we can
    # assert created/updated user_group_member_role.member_role == member.role
    create(:group_group_link, :developer, shared_group: group, shared_with_group: shared_with_group)
  end

  def fetch_records(user, group, member_role)
    user.user_group_member_roles.where(group: group, member_role: member_role)
  end

  it 'creates a UserGroupMemberRole record for the user in the group' do
    expect { execute }.to change {
      fetch_records(user, group, member.member_role).exists?
    }.from(false).to(true)
  end

  context 'with an existing UserGroupMemberRole record' do
    let_it_be(:old_role) { create(:member_role, :guest, namespace: group) }

    before do
      create_record(user, group, old_role)
    end

    it 'updates member_role_id of the existing record' do
      expect { execute }.to change {
        Authz::UserGroupMemberRole.for_user_in_group(user, group).member_role_id
      }.from(old_role.id).to(role.id)

      expect(user.user_group_member_roles.count).to eq(1)
    end

    context 'when member role is removed' do
      before do
        member.update!(member_role: nil)
      end

      it 'deletes the existing record' do
        expect { execute }.to change { user.user_group_member_roles.count }.from(1).to(0)
      end
    end
  end

  context 'when there are groups shared to the group' do
    let_it_be(:shared_group) { create(:group) }

    before do
      create_group_group_link(shared_group, group)
    end

    it 'creates UserGroupMemberRole records for the user in the group and in the shared group' do
      expect { execute }.to change {
        [
          fetch_records(user, group, role).exists?,
          fetch_records(user, shared_group, role).exists?
        ]
      }.from([false, false]).to([true, true])
    end

    context 'with existing UserGroupMemberRole records' do
      let_it_be(:old_role) { create(:member_role, :guest, namespace: group) }
      let_it_be(:shared_group_role) { create(:member_role, :guest, namespace: shared_group) }

      before do
        create_record(user, group, old_role)
        create_record(user, shared_group, old_role, shared_with_group: group)
      end

      it 'updates member_role_id of the existing records' do
        expect { execute }.to change {
          [
            Authz::UserGroupMemberRole.for_user_in_group(user, group).member_role_id,
            Authz::UserGroupMemberRole
              .where(user: user, group: shared_group).where.not(shared_with_group: nil).first
              .member_role_id
          ]
        }.from([old_role.id, old_role.id]).to([role.id, role.id])

        expect(user.user_group_member_roles.count).to eq(2)
      end

      context 'when member role is removed' do
        before do
          member.update!(member_role: nil)
        end

        it 'deletes the existing records' do
          expect { execute }.to change { user.user_group_member_roles.count }.from(2).to(0)
        end
      end
    end
  end

  context 'when membership is pending' do
    before do
      create_group_group_link(create(:group), group)

      member.update!(requested_at: Time.zone.now)
    end

    it 'does not create any UserGroupMemberRole record for the user' do
      expect { execute }.not_to change {
        user.user_group_member_roles.count
      }.from(0)
    end
  end

  context 'when membership is inactive' do
    before do
      create_group_group_link(create(:group), group)

      member.update!(state: Member::STATE_AWAITING)
    end

    it 'does not create any UserGroupMemberRole record for the user' do
      expect { execute }.not_to change {
        user.user_group_member_roles.count
      }.from(0)
    end
  end
end
