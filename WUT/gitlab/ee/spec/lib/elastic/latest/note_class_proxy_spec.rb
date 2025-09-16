# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::NoteClassProxy, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  subject(:proxy) { described_class.new(Note, use_separate_indices: true) }

  describe '#es_type' do
    it 'returns notes' do
      expect(proxy.es_type).to eq 'note'
    end
  end

  describe '#elastic_search', :elastic, :sidekiq_inline do
    let_it_be(:user) { create :user }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create :project, :public, group: group }
    let_it_be(:project2) { create :project, :public }
    let_it_be(:archived_project) { create :project, :archived, :public }
    let_it_be(:note) { create(:note_on_issue, note: 'test', project: project) }
    let_it_be(:note2) { create(:note_on_merge_request, note: 'test', project: project2) }
    let_it_be(:note3) { create(:note_on_merge_request, note: 'test', project: project) }
    let_it_be(:archived_note) { create(:note_on_issue, note: 'test', project: archived_project) }

    let(:base_options) do
      {
        current_user: user,
        project_ids: project_ids,
        group_ids: group_ids,
        public_and_internal_projects: public_and_internal_projects,
        search_level: search_level
      }
    end

    let(:options) { base_options }
    let(:query) { 'test' }
    let(:result) { proxy.elastic_search(query, options: options) }

    before_all do
      Elastic::ProcessBookkeepingService.track!(note, note2, note3, archived_note)
      ensure_elasticsearch_index!
    end

    describe 'global search' do
      let(:search_level) { :global }
      let(:project_ids) { [] }
      let(:group_ids) { [] }
      let(:public_and_internal_projects) { true }

      context 'when options[:include_archived] is true' do
        let(:options) { base_options.merge(include_archived: true) }

        it 'returns archived results' do
          expect(elasticsearch_hit_ids(result)).to match_array [note.id, note2.id, note3.id, archived_note.id]
          assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
            without: ['note:archived:non_archived'])
        end
      end

      it 'returns non-archived results by default' do
        expect(elasticsearch_hit_ids(result)).to match_array [note.id, note2.id, note3.id]
        assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
          'note:archived:non_archived')
      end

      context 'when advanced search syntax is used' do
        let(:query) { 'test*' }

        it 'uses simple_query_string in query' do
          expect(elasticsearch_hit_ids(result)).to match_array [note.id, note2.id, note3.id]
          assert_named_queries('note:match:search_terms',
            without: %w[note:multi_match:and:search_terms note:multi_match_phrase:search_terms])
        end
      end

      context 'when options[:noteable_type] is set' do
        let(:options) { base_options.merge(noteable_type: 'Issue') }

        it 'filters by noteable_type and returns noteable_id only in the _source array' do
          expect(result.response['hits']['hits'].first['_source'].keys).to contain_exactly('noteable_id')
          expect(result.response['hits']['hits'].map(&:_source).map(&:noteable_id)).to contain_exactly(note.noteable_id)
          assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
            'note:archived:non_archived', 'filters:related:issue')
        end
      end
    end

    describe 'group search' do
      let(:search_level) { :group }
      let(:group_ids) { [group.id] }
      let(:public_and_internal_projects) { false }
      let(:project_ids) do
        all_projects = ::ProjectsFinder.new(current_user: user).execute
        all_projects.preload(:topics, :project_topics, :route).inside_path(group.full_path).pluck_primary_key
      end

      it 'returns results' do
        expect(elasticsearch_hit_ids(result)).to match_array [note.id, note3.id]
        assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
          'note:archived:non_archived')
      end

      context 'when advanced search syntax is used' do
        let(:query) { 'test*' }

        it 'uses simple_query_string in query' do
          expect(elasticsearch_hit_ids(result)).to match_array [note.id, note3.id]

          assert_named_queries('note:match:search_terms',
            without: %w[note:multi_match:and:search_terms note:multi_match_phrase:search_terms])
        end
      end

      context 'when options[:noteable_type] is set' do
        let(:options) { base_options.merge(noteable_type: 'Issue') }

        it 'filters by noteable_type and returns noteable_id only in the _source array' do
          expect(result.response['hits']['hits'].first['_source'].keys).to contain_exactly('noteable_id')
          expect(result.response['hits']['hits'].map(&:_source).map(&:noteable_id)).to contain_exactly(note.noteable_id)
          assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
            'note:archived:non_archived', 'filters:related:issue')
        end
      end
    end

    describe 'project search' do
      let(:search_level) { :project }
      let(:project_ids) { [project.id] }
      let(:group_ids) { [] }
      let(:public_and_internal_projects) { false }

      it 'returns results' do
        expect(elasticsearch_hit_ids(result)).to match_array [note.id, note3.id]
        assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
          'note:archived:non_archived')
      end

      context 'when advanced search syntax is used' do
        let(:query) { 'test*' }

        it 'uses simple_query_string in query' do
          expect(elasticsearch_hit_ids(result)).to match_array [note.id, note3.id]

          assert_named_queries('note:match:search_terms',
            without: %w[note:multi_match:and:search_terms note:multi_match_phrase:search_terms])
        end
      end

      context 'when options[:noteable_type] is set' do
        let(:options) { base_options.merge(noteable_type: 'MergeRequest') }

        it 'ignores noteable_type and returns noteable_id only in the _source array' do
          hits = result.response['hits']['hits']
          expect(hits.first['_source'].keys).to contain_exactly('noteable_id')
          expect(hits.map(&:_source).map(&:noteable_id)).to contain_exactly(note3.noteable_id)
          assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
            'note:archived:non_archived', 'filters:related:mergerequest')
        end
      end
    end
  end
end
