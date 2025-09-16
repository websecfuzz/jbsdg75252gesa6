# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Com, feature_category: :shared do
  it { expect(described_class.l1_cache_backend).to eq(Gitlab::ProcessMemoryCache.cache_backend) }
  it { expect(described_class.l2_cache_backend).to eq(Rails.cache) }

  describe '.gitlab_com_group_member?' do
    subject(:gitlab_com_group_member?) { described_class.gitlab_com_group_member?(user_or_id) }

    let_it_be(:user) { create(:user) }
    let(:user_or_id) { user }

    before do
      allow(Gitlab).to receive(:com?).and_return(true)
      allow(Gitlab).to receive(:jh?).and_return(false)
    end

    context 'when user is a gitlab team member' do
      include_context 'gitlab team member'

      it { is_expected.to be true }

      context 'when passed an user id' do
        let(:user_or_id) { user.id }

        it { is_expected.to be true }
      end

      describe 'caching of allowed user IDs' do
        before do
          described_class.gitlab_com_group_member?(user)
        end

        it_behaves_like 'allowed user IDs are cached'
      end

      context 'when not on Gitlab.com' do
        before do
          allow(Gitlab).to receive(:com?).and_return(false)
        end

        it { is_expected.to be false }
      end

      context 'when on JiHu' do
        before do
          allow(Gitlab).to receive(:jh?).and_return(true)
        end

        it { is_expected.to be false }
      end
    end

    context 'when user is not a gitlab team member' do
      it { is_expected.to be false }

      context 'when passed an user id' do
        let(:user_or_id) { user.id }

        it { is_expected.to be false }
      end

      describe 'caching of allowed user IDs' do
        before do
          described_class.gitlab_com_group_member?(user)
        end

        it_behaves_like 'allowed user IDs are cached'

        it 'caches the IDs in the request store', :request_store do
          gitlab_com_group_member?

          expect do
            expect(described_class.l1_cache_backend).not_to receive(:fetch)
            expect(described_class.l2_cache_backend).not_to receive(:fetch)
            expect(gitlab_com_group_member?).to be_truthy
          end.not_to exceed_query_limit(0)
        end
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it { is_expected.to be false }
    end

    context 'when subject is not a user or integer' do
      include_context 'gitlab team member'

      let(:user_or_id) { build_stubbed(:group_member, source: namespace) }

      it { is_expected.to be false }
    end

    context 'when gitlab-com group does not exist' do
      before do
        allow(Group).to receive(:find_by_name).and_return(nil)
      end

      it { is_expected.to be false }
    end
  end
end
