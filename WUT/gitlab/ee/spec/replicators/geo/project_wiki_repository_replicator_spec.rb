# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectWikiRepositoryReplicator, feature_category: :geo_replication do
  let(:project) { create(:project, :wiki_repo, wiki_repository: build(:project_wiki_repository, project: nil)) }
  let(:model_record) { project.wiki_repository }

  include_examples 'a repository replicator' do
    let(:housekeeping_model_record) { model_record.wiki }

    describe '#verify' do
      context 'when wiki git repository does not exist' do
        let(:project) { create(:project, wiki_repository: build(:project_wiki_repository, project: nil)) }
        let(:model_record) { project.wiki_repository }

        it 'creates an empty git repository' do
          expect { replicator.verify }
            .to change { model_record.repository.exists? }
            .from(false)
            .to(true)

          expect(replicator.primary_checksum).to be_present
        end
      end
    end
  end
end
