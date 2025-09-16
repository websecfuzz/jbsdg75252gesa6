# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::MergeRequestQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:base_options) do
    {
      current_user: user,
      search_level: 'global',
      project_ids: project_ids,
      group_ids: [],
      public_and_internal_projects: true
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      merge_request:multi_match:and:search_terms
      merge_request:multi_match_phrase:search_terms
      filters:not_hidden
      filters:non_archived
    ])
  end

  describe 'query' do
    context 'when query is an iid' do
      let(:query) { '!1' }

      it 'returns the expected query' do
        assert_names_in_query(build, with: %w[merge_request:related:iid doc:is_a:merge_request])
      end
    end

    context 'when query is text' do
      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[
            merge_request:multi_match:and:search_terms
            merge_request:multi_match_phrase:search_terms
          ],
          without: %w[merge_request:match:search_terms])
      end

      context 'when advanced query syntax is used' do
        let(:query) { 'foo -default' }

        it 'returns the expected query' do
          assert_names_in_query(build, with: %w[merge_request:match:search_terms],
            without: %w[merge_request:multi_match:and:search_terms merge_request:multi_match_phrase:search_terms])
        end
      end
    end

    context 'when the query is with fields' do
      let(:options) { base_options.merge(fields: ['title']) }

      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[
            merge_request:multi_match:and:search_terms
            merge_request:multi_match_phrase:search_terms
          ],
          without: %w[merge_request:match:search_terms])
        assert_fields_in_query(build, with: %w[title])
      end
    end
  end

  describe 'filters' do
    let_it_be(:private_project) { create(:project, :private) }
    let_it_be(:authorized_project) { create(:project, developers: [user]) }
    let_it_be(:user) { create(:user) }
    let_it_be(:label) { create(:label, project: authorized_project) }
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'
    it_behaves_like 'a query filtered by hidden'
    it_behaves_like 'a query filtered by state'
    it_behaves_like 'a query filtered by author'
    it_behaves_like 'a query filtered by labels'

    describe 'authorization' do
      it 'applies authorization filters' do
        assert_names_in_query(build, with: %w[filters:project:membership:id])
      end
    end

    describe 'source_branch' do
      it 'does not apply filters by default' do
        assert_names_in_query(build, without: %w[filters:source_branch filters:not_source_branch])
      end

      context 'when source_branch option is provided' do
        let(:options) { base_options.merge(source_branch: 'hello') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:source_branch])
        end
      end

      context 'when not_source_branch option is provided' do
        let(:options) { base_options.merge(not_source_branch: 'world') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_source_branch])
        end
      end
    end

    describe 'target_branch' do
      it 'does not apply filters by default' do
        assert_names_in_query(build, without: %w[filters:target_branch filters:not_target_branch])
      end

      context 'when target_branch option is provided' do
        let(:options) { base_options.merge(target_branch: 'hello') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:target_branch])
        end
      end

      context 'when not_target_branch option is provided' do
        let(:options) { base_options.merge(not_target_branch: 'world') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_target_branch])
        end
      end
    end
  end

  it_behaves_like 'a sorted query'

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
  end
end
