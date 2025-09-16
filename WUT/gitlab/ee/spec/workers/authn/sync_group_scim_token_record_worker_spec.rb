# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::SyncGroupScimTokenRecordWorker, feature_category: :system_access do
  let_it_be(:group) { create(:group) }

  let(:worker) { described_class.new }
  let(:group_scim_token) { create(:group_scim_auth_access_token, group: group) }
  let(:args) { { 'group_scim_token_id' => group_scim_token.id } }

  describe '#perform' do
    subject(:perform_worker) { worker.perform(args) }

    context 'when group_scim_token exists' do
      context 'when no matching scim token exists' do
        before do
          group_scim_token.update!(temp_source_id: 123)
        end

        it 'initializes a new scim_token with matching id' do
          expect { perform_worker }.to change { ScimOauthAccessToken.count }.by(1)

          scim_token = ScimOauthAccessToken.find_by(group: group_scim_token.group)

          expect(scim_token).to have_attributes(
            group: group,
            token_encrypted: group_scim_token.token_encrypted
          )
        end
      end

      context 'when matching scim token exists' do
        let!(:existing_scim_token) do
          create(:scim_oauth_access_token,
            id: group_scim_token.temp_source_id,
            group: group)
        end

        before do
          group_scim_token.update!(temp_source_id: existing_scim_token.id)
        end

        context 'when group_scim_token is more recent' do
          before do
            group_scim_token.update!(updated_at: existing_scim_token.updated_at + 1.day)
          end

          it 'updates the existing scim_token' do
            expect { perform_worker }.not_to change { ScimOauthAccessToken.count }

            expect(existing_scim_token.reload).to have_attributes(
              group: group,
              token_encrypted: group_scim_token.token_encrypted
            )
          end
        end

        context 'when group_scim_token is older' do
          before do
            travel_to(group_scim_token.updated_at + 1.day) do
              existing_scim_token.touch
            end
          end

          it 'preserves the existing scim_token' do
            original_token_encrypted = existing_scim_token.token_encrypted

            expect { perform_worker }.not_to change { ScimOauthAccessToken.count }

            expect(existing_scim_token.reload).to have_attributes(
              token_encrypted: original_token_encrypted
            )
          end
        end
      end
    end

    context 'when group_scim_token does not exist' do
      let(:args) { { 'group_scim_token_id' => non_existing_record_id } }

      it 'does nothing' do
        expect { perform_worker }.not_to change { ScimOauthAccessToken.count }
      end
    end
  end
end
