# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'commits', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project_1) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:project_2) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:limit_project_ids) { [project_1.id] }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'commits', :elastic_delete_by_query, :sidekiq_inline do
    before do
      project_1.repository.index_commits_and_blobs
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'commits'

    it 'finds commits' do
      results = described_class.new(user, 'add', limit_project_ids)
      commits = results.objects('commits')

      expect(commits.first.message.downcase).to include("add")
      expect(results.commits_count).to eq 21
    end

    it 'finds commits from public projects only' do
      project_2 = create :project, :private, :repository
      project_2.repository.index_commits_and_blobs
      project_2.add_reporter(user)
      ensure_elasticsearch_index!

      results = described_class.new(user, 'add', [project_1.id])
      expect(results.commits_count).to eq 21

      results = described_class.new(user, 'add', [project_1.id, project_2.id])
      expect(results.commits_count).to eq 42
    end

    it 'returns zero when commits are not found' do
      results = described_class.new(user, 'asdfg', limit_project_ids)

      expect(results.commits_count).to eq 0
    end
  end
end
