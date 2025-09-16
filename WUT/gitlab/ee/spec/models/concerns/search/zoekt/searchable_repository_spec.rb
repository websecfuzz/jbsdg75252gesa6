# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::SearchableRepository, :zoekt, feature_category: :global_search do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:repository) { project.repository }

  describe '#use_zoekt?' do
    let_it_be(:unindexed_project) { create(:project, :repository) }
    let(:unindexed_repository) { unindexed_project.repository }
    let_it_be(:private_project) { create(:project, :repository, namespace: project.namespace) }
    let(:private_repository) { private_project.repository }

    before do
      stub_licensed_features(zoekt_code_search: true)
      stub_ee_application_setting(zoekt_indexing_enabled: true)
      zoekt_ensure_project_indexed!(project)
    end

    it 'is true for indexed projects' do
      expect(repository.use_zoekt?).to be true
    end

    it 'is false for unindexed projects' do
      expect(unindexed_repository.use_zoekt?).to be false
    end

    it 'is true for private projects with new indexer' do
      expect(private_repository.use_zoekt?).to be true
    end
  end

  describe '#async_update_zoekt_index' do
    it 'makes updates available via ::Search::Zoekt' do
      expect(::Search::Zoekt).to receive(:index_async).with(project.id)

      repository.async_update_zoekt_index
    end
  end
end
