# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Users::BannedUser, feature_category: :global_search do
  include ElasticsearchHelpers

  let_it_be(:user) { create :user }
  let(:banned_user) { create :banned_user, user: user }

  describe '#after_commit' do
    it 'does not call reindex_issues on update' do
      banned_user
      expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async)
      banned_user.touch
    end

    it 'calls reindex_issues on create' do
      expect(ElasticAssociationIndexerWorker).to receive(:perform_async).with(user.class.name, user.id,
        %i[issues merge_requests])
      banned_user
    end

    it 'calls reindex_issues on destroy' do
      banned_user
      expect(ElasticAssociationIndexerWorker).to receive(:perform_async).with(user.class.name, user.id,
        [:issues, :merge_requests])
      banned_user.destroy!
    end

    it 'does not call reindex on merge_requests association for update' do
      banned_user
      expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async).with(user.class.name, user.id,
        array_including(:merge_requests))
      banned_user.touch
    end

    it 'calls reindex on merge_requests association for create' do
      expect(ElasticAssociationIndexerWorker).to receive(:perform_async).with(user.class.name, user.id,
        array_including(:merge_requests))
      banned_user
    end

    it 'calls reindex on merge_requests association for destroy' do
      banned_user
      expect(ElasticAssociationIndexerWorker).to receive(:perform_async).with(user.class.name, user.id,
        array_including(:merge_requests))
      banned_user.destroy!
    end
  end
end
