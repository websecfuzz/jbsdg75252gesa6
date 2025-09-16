# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::SyncScimIdentityRecordWorker, feature_category: :system_access do
  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let(:scim_identity) do
    create(:scim_identity,
      user: user,
      group: group,
      extern_uid: 'test-extern-uid',
      active: true)
  end

  let(:args) { { 'scim_identity_id' => scim_identity.id } }

  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when scim_identity exists' do
      it 'creates a new group_scim_identity' do
        expect { worker.perform(args) }
          .to change { GroupScimIdentity.count }.by(1)

        group_scim_identity = GroupScimIdentity.last
        expect(group_scim_identity.temp_source_id).to eq(scim_identity.id)
        expect(group_scim_identity.extern_uid).to eq(scim_identity.extern_uid)
        expect(group_scim_identity.user).to eq(scim_identity.user)
        expect(group_scim_identity.group).to eq(scim_identity.group)
        expect(group_scim_identity.active).to eq(scim_identity.active)
        expect(group_scim_identity.created_at).to be_within(1.second).of(scim_identity.created_at)
        expect(group_scim_identity.updated_at).to be_within(1.second).of(scim_identity.updated_at)
      end

      context 'when group_scim_identity already exists' do
        let!(:group_scim_identity) do
          create(:group_scim_identity,
            temp_source_id: scim_identity.id,
            extern_uid: 'old-extern-uid',
            user: user,
            group: group,
            active: false,
            updated_at: 1.day.ago)
        end

        before do
          scim_identity.update!(extern_uid: 'new-extern-uid', active: true)
        end

        it 'updates existing group_scim_identity' do
          expect { worker.perform(args) }
            .not_to change { GroupScimIdentity.count }

          group_scim_identity.reload
          expect(group_scim_identity.extern_uid).to eq('new-extern-uid')
          expect(group_scim_identity.active).to be(true)
          expect(group_scim_identity.updated_at).to be_within(1.second).of(scim_identity.updated_at)
        end

        context 'when scim_identity is not newer' do
          before do
            group_scim_identity.update!(updated_at: 1.day.from_now)
          end

          it 'does not update group_scim_identity' do
            expect { worker.perform(args) }
              .not_to change { group_scim_identity.reload.updated_at }
          end
        end
      end
    end

    context 'when scim_identity does not exist' do
      let(:args) { { 'scim_identity_id' => non_existent_id } }
      let(:non_existent_id) { ScimIdentity.maximum(:id).to_i + 1 }

      it 'does nothing' do
        expect { worker.perform(args) }
          .not_to change { GroupScimIdentity.count }
      end
    end
  end
end
