# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupScimAuthAccessToken, type: :model, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:group) }
  end

  describe '.token_matches_for_group?' do
    context 'when token passed in found in database' do
      context 'when token associated with group passed in' do
        it 'returns true' do
          group = create(:group)
          token = create(:group_scim_auth_access_token, group: group)
          token_value = token.token

          expect(
            described_class.token_matches_for_group?(token_value, group)
          ).to be true
        end
      end

      context 'when token not associated with group passed in' do
        it 'returns false' do
          other_group = create(:group)
          token = create(:group_scim_auth_access_token, group: create(:group))
          token_value = token.token

          expect(
            described_class.token_matches_for_group?(token_value, other_group)
          ).to be false
        end
      end
    end

    context 'when token passed in is not found in database' do
      it 'returns nil' do
        group = create(:group)

        expect(
          described_class.token_matches_for_group?('notatoken', group)
        ).to be_nil
      end
    end
  end

  describe '#token' do
    it 'generates a token on creation' do
      token = described_class.create!(group: create(:group))

      expect(token.token).to be_a(String)
    end

    it 'is prefixed' do
      token = create(:group_scim_auth_access_token)

      expect(token.token).to match(/^#{described_class::TOKEN_PREFIX}[\w-]{20}$/o)
    end
  end
end
