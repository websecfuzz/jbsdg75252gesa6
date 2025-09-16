# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::GroupWikiRepositoryReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:group_wiki_repository, group: create(:group)) }

  include_examples 'a repository replicator' do
    describe '#verify' do
      context 'when wiki git repository does not exist' do
        it 'creates an empty git repository' do
          expect { replicator.verify }
            .to change { model_record.repository.exists? }
            .from(false)
            .to(true)

          expect(replicator.primary_checksum).to be_present
        end

        it 'logs an error message' do
          message =
            'Git repository of group wiki was not found. To avoid verification error, creating empty Git repository'

          expect(Gitlab::Geo::Logger)
            .to receive(:error)
            .with(
              hash_including(
                message: message,
                group_wiki_repository_id: model_record.id,
                group_id: model_record.group_id
              )
            )

          replicator.verify
        end
      end
    end
  end
end
