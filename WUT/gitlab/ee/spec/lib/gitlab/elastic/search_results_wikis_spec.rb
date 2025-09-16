# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'wikis', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project_1) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:project_2) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:limit_project_ids) { [project_1.id] }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'wikis', :elastic_delete_by_query, :sidekiq_inline do
    let(:results) { described_class.new(user, 'term', limit_project_ids) }

    subject(:wiki_blobs) { results.objects('wiki_blobs') }

    before do
      if project_1.wiki_enabled?
        project_1.wiki.create_page('index_page', 'term')
        project_1.wiki.index_wiki_blobs
      end

      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'wiki_blobs'

    it 'finds wiki blobs' do
      blobs = results.objects('wiki_blobs')

      expect(blobs.first.data).to include('term')
      expect(results.wiki_blobs_count).to eq 1
    end

    it 'finds wiki blobs for guest' do
      project_1.add_guest(user)
      blobs = results.objects('wiki_blobs')

      expect(blobs.first.data).to include('term')
      expect(results.wiki_blobs_count).to eq 1
    end

    it 'finds wiki blobs from public projects only' do
      project_2 = create :project, :repository, :private, :wiki_repo
      project_2.wiki.create_page('index_page', 'term')
      project_2.wiki.index_wiki_blobs
      project_2.add_guest(user)
      ensure_elasticsearch_index!

      expect(results.wiki_blobs_count).to eq 1

      results = described_class.new(user, 'term', [project_1.id, project_2.id])
      expect(results.wiki_blobs_count).to eq 2
    end

    it 'returns zero when wiki blobs are not found' do
      results = described_class.new(user, 'asdfg', limit_project_ids)

      expect(results.wiki_blobs_count).to eq 0
    end

    context 'when wiki is disabled' do
      let_it_be(:project_1) { create(:project, :public, :repository, :wiki_disabled) }

      context 'when searching by member' do
        let(:limit_project_ids) { [project_1.id] }

        it { is_expected.to be_empty }
      end

      context 'when searching by non-member' do
        let(:limit_project_ids) { [] }

        it { is_expected.to be_empty }
      end
    end

    context 'when wiki is internal' do
      let_it_be(:project_1) { create(:project, :public, :repository, :wiki_private, :wiki_repo) }

      context 'when searching by member' do
        let_it_be(:limit_project_ids) { [project_1.id] }

        before_all do
          project_1.add_guest(user)
        end

        it { is_expected.not_to be_empty }
      end

      context 'when searching by non-member' do
        let(:limit_project_ids) { [] }

        it { is_expected.to be_empty }
      end
    end

    context 'for group wiki' do
      let_it_be(:sub_group) { create(:group, :nested) }
      let_it_be(:sub_group_wiki) { create(:group_wiki, group: sub_group) }
      let_it_be(:parent_group) { sub_group.parent }
      let_it_be(:parent_group_wiki) { create(:group_wiki, group: parent_group) }
      let_it_be(:group_project) { create(:project, :public, :in_group) }
      let_it_be(:group_project_wiki) { create(:project_wiki, project: group_project, user: user) }

      before do
        [parent_group_wiki, sub_group_wiki, group_project_wiki].each do |wiki|
          wiki.create_page('index_page', 'term')
          wiki.index_wiki_blobs
        end
        ElasticWikiIndexerWorker.new.perform(project_1.id, project_1.class.name, 'force' => true)
        ensure_elasticsearch_index!
      end

      it 'includes all the wikis from groups, subgroups, projects and projects within the group' do
        expect(results.wiki_blobs_count).to eq 4
        wiki_containers = wiki_blobs.filter_map { |blob| blob.group_level_blob ? blob.group : blob.project }.uniq
        expect(wiki_containers).to contain_exactly(parent_group, sub_group, group_project, project_1)
      end
    end

    describe 'searches with various characters in wiki', :aggregate_failures do
      let_it_be(:page_prefix) { SecureRandom.hex(8) }

      before do
        code_examples.values.uniq.each do |page_content|
          page_title = "#{page_prefix}-#{Digest::SHA256.hexdigest(page_content)}"
          project_1.wiki.create_page(page_title, page_content)
        end

        text_examples.values.uniq.each do |page_content|
          page_title = "#{page_prefix}-#{Digest::SHA256.hexdigest(page_content)}"
          project_1.wiki.create_page(page_title, page_content)
        end

        project_1.wiki.index_wiki_blobs
        ensure_elasticsearch_index!
      end

      include_context 'with code examples' do
        it 'finds all examples in wiki' do
          code_examples.each do |search_term, page_content|
            page_title = "#{page_prefix}-#{Digest::SHA256.hexdigest(page_content)}.md"
            expect(search_for(search_term)).to include(page_title), "failed to find #{search_term} in wiki"
          end
        end
      end

      include_context 'with text examples' do
        it 'finds all examples in wiki' do
          text_examples.each do |search_term, page_content|
            page_title = "#{page_prefix}-#{Digest::SHA256.hexdigest(page_content)}.md"
            expect(search_for(search_term)).to include(page_title), "failed to find #{search_term} in wiki"
          end
        end
      end

      def search_for(term)
        described_class.new(user, term, limit_project_ids).objects('wiki_blobs').map(&:path)
      end
    end
  end
end
