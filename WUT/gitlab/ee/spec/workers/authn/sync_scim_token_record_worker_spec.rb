# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::SyncScimTokenRecordWorker, feature_category: :system_access do
  let_it_be(:group) { create(:group) }

  let(:worker) { described_class.new }
  let(:scim_token) { create(:scim_oauth_access_token, group: group) }
  let(:args) { { 'group_scim_token_id' => scim_token.id } }

  describe '#perform' do
    subject(:perform_worker) { worker.perform(args) }

    context 'when scim_token exists' do
      context 'when group has no existing scim token' do
        it 'creates a new group_scim_token record' do
          expect { perform_worker }.to change { GroupScimAuthAccessToken.count }.by(1)

          group_scim_token = GroupScimAuthAccessToken.last

          expect(group_scim_token).to have_attributes(
            group: group,
            temp_source_id: scim_token.id
          )
          expect(GroupScimAuthAccessToken.find_by_token(scim_token.token)).to eq(group_scim_token)
        end
      end

      context 'when group has an existing scim token' do
        let!(:existing_group_token) do
          create(:group_scim_auth_access_token,
            group: group,
            temp_source_id: scim_token.id)
        end

        context 'when scim_token is more recent' do
          before do
            scim_token.update!(updated_at: 1.day.from_now)
          end

          it 'updates the existing group_scim_token' do
            original_token = existing_group_token.token
            existing_group_token.reset_token!

            expect { perform_worker }.not_to change { GroupScimAuthAccessToken.count }

            expect(GroupScimAuthAccessToken.find_by_token(original_token)).not_to eq(existing_group_token)
            expect(GroupScimAuthAccessToken.find_by_token(scim_token.token)).to eq(existing_group_token)
          end
        end

        context 'when scim_token is older' do
          before do
            existing_group_token.update!(updated_at: 1.day.from_now)
          end

          it 'preserves the existing group_scim_token' do
            original_token = existing_group_token.token

            expect { perform_worker }.not_to change { GroupScimAuthAccessToken.count }

            expect(GroupScimAuthAccessToken.find_by_token(original_token)).to eq(existing_group_token)
            expect(GroupScimAuthAccessToken.find_by_token(scim_token.token)).not_to eq(existing_group_token)
          end
        end
      end
    end

    context 'when scim_token does not exist' do
      let(:args) { { 'group_scim_token_id' => non_existing_record_id } }

      it 'does nothing' do
        expect { perform_worker }.not_to change { GroupScimAuthAccessToken.count }
      end
    end
  end
end
