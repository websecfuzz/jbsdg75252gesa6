# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::MilestoneQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:base_options) do
    {
      current_user: user,
      project_ids: project_ids,
      group_ids: [],
      search_level: 'global',
      public_and_internal_projects: true
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      milestone:multi_match:and:search_terms
      milestone:multi_match_phrase:search_terms
      filters:doc:is_a:milestone
      filters:project
      filters:project:visibility:10
      filters:project:visibility:20
      filters:project:visibility:20:issues:access_level:enabled
      filters:project:visibility:20:merge_requests:access_level:enabled
      filters:project
      filters:non_archived
    ])
  end

  context 'when advanced query syntax is used' do
    let(:query) { 'foo -default' }

    it 'uses simple_query_string in query' do
      assert_names_in_query(build, with: %w[milestone:match:search_terms],
        without: %w[milestone:multi_match:and:search_terms milestone:multi_match_phrase:search_terms])
    end
  end

  describe 'filters' do
    let_it_be(:private_project) { create(:project, :private) }
    let_it_be(:authorized_project) { create(:project, developers: [user]) }
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'

    describe 'authorization' do
      it 'applies authorization filters' do
        assert_names_in_query(build, with: %w[filters:project])
      end
    end
  end

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
  end
end
