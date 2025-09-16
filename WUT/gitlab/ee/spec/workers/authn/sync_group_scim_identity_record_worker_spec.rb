# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::SyncGroupScimIdentityRecordWorker, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:worker) { described_class.new }
  let(:group_scim_identity) do
    create(:group_scim_identity,
      group: group,
      user: user,
      extern_uid: 'test-extern-uid',
      active: true)
  end

  let(:args) { { 'group_scim_identity_id' => group_scim_identity.id } }

  describe '#perform' do
    subject(:perform_worker) { worker.perform(args) }

    context 'when group_scim_identity exists' do
      context 'when no matching scim identity exists' do
        before do
          group_scim_identity.update!(temp_source_id: 123)
        end

        it 'initializes a new scim_identity with matching id' do
          expect { perform_worker }.to change { ScimIdentity.count }.by(1)

          group_scim_identity.reload
          scim_identity = ScimIdentity.find_by(id: group_scim_identity.temp_source_id)

          expect(scim_identity).to have_attributes(
            id: group_scim_identity.temp_source_id,
            group: group,
            user: user,
            extern_uid: group_scim_identity.extern_uid,
            active: group_scim_identity.active,
            created_at: be_within(1.second).of(group_scim_identity.created_at),
            updated_at: be_within(1.second).of(group_scim_identity.updated_at)
          )

          expect(group_scim_identity.reload.temp_source_id).to eq(scim_identity.id)
        end
      end

      context 'when matching scim identity exists' do
        let!(:existing_scim_identity) do
          create(:scim_identity,
            id: group_scim_identity.temp_source_id,
            group: group,
            user: user,
            extern_uid: 'old-extern-uid',
            active: false)
        end

        before do
          group_scim_identity.update!(temp_source_id: existing_scim_identity.id)
        end

        context 'when group_scim_identity is more recent' do
          before do
            group_scim_identity.update!(updated_at: existing_scim_identity.updated_at + 1.day)
          end

          it 'updates the existing scim_identity' do
            expect { perform_worker }.not_to change { ScimIdentity.count }

            expect(existing_scim_identity.reload).to have_attributes(
              group: group,
              user: user,
              extern_uid: group_scim_identity.extern_uid,
              active: group_scim_identity.active,
              created_at: be_within(1.second).of(group_scim_identity.created_at),
              updated_at: be_within(1.second).of(group_scim_identity.updated_at)
            )

            expect(group_scim_identity.reload.temp_source_id).to eq(existing_scim_identity.id)
          end
        end

        context 'when group_scim_identity is older' do
          before do
            travel_to(group_scim_identity.updated_at + 1.day) do
              existing_scim_identity.touch
            end
            existing_scim_identity.reload
          end

          it 'preserves the existing scim_identity' do
            original_attributes = {
              extern_uid: existing_scim_identity.extern_uid,
              active: existing_scim_identity.active,
              created_at: existing_scim_identity.created_at,
              updated_at: existing_scim_identity.updated_at
            }

            expect { perform_worker }.not_to change { ScimIdentity.count }

            expect(existing_scim_identity.reload).to have_attributes(original_attributes)
            expect(group_scim_identity.reload.temp_source_id).to eq(existing_scim_identity.id)
          end
        end
      end
    end

    context 'when group_scim_identity does not exist' do
      let(:args) { { 'group_scim_identity_id' => non_existing_record_id } }

      it 'does nothing' do
        expect { perform_worker }.not_to change { ScimIdentity.count }
      end
    end
  end
end
