# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::IssueQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:base_options) do
    {
      current_user: user,
      search_level: 'global',
      project_ids: project_ids,
      group_ids: [],
      public_and_internal_projects: false
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      issue:multi_match:and:search_terms
      issue:multi_match_phrase:search_terms
      filters:not_hidden
      filters:non_archived
      filters:non_confidential
      filters:confidential
      filters:confidential:as_author
      filters:confidential:as_assignee
      filters:confidential:project:membership:id
    ])
  end

  describe 'query' do
    context 'when query is an iid' do
      let(:query) { '#1' }

      it 'returns the expected query' do
        assert_names_in_query(build, with: %w[issue:related:iid doc:is_a:issue])
      end
    end

    context 'when query is text' do
      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[
            issue:multi_match:and:search_terms
            issue:multi_match_phrase:search_terms
          ],
          without: %w[issue:match:search_terms])
      end

      context 'when advanced query syntax is used' do
        let(:query) { 'foo -default' }

        it 'returns the expected query' do
          assert_names_in_query(build,
            with: %w[issue:match:search_terms],
            without: %w[
              issue:multi_match:and:search_terms
              issue:multi_match_phrase:search_terms
            ])
        end
      end
    end
  end

  describe 'filters' do
    let_it_be(:private_project) { create(:project, :private) }
    let_it_be(:authorized_project) { create(:project, developers: [user]) }
    let_it_be(:label) { create(:label, project: authorized_project, title: 'My Label') }
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'
    it_behaves_like 'a query filtered by hidden'
    it_behaves_like 'a query filtered by state'
    it_behaves_like 'a query filtered by confidentiality'
    it_behaves_like 'a query filtered by labels'

    describe 'authorization' do
      it 'applies authorization filters' do
        assert_names_in_query(build, with: %w[filters:project:membership:id])
      end
    end
  end

  it_behaves_like 'a sorted query'

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
    it_behaves_like 'a query that is paginated'
  end
end
