# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::ProjectQueryBuilder, :elastic_helpers, feature_category: :global_search do
  using RSpec::Parameterized::TableSyntax
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  # rubocop:disable Layout/LineLength -- keep the table intact
  where(:search_level, :projects, :groups, :admin_mode_enabled, :expected_filter) do
    'global' | :any | [] | false | %w[filters:permissions:global:visibility_level:public_and_internal]
    'global' | :any | [] | true | %w[]
    'global' | [] | [] | false | %w[filters:permissions:global:visibility_level:public_and_internal]
    'group' | :any | [ref(:group)] | false | %w[filters:level:group filters:permissions:group:visibility_level:public_and_internal]
    'group' | :any | [ref(:group)] | true | %w[filters:level:group]
    'group' | [] | [ref(:group)] | false | %w[filters:level:group filters:permissions:group:visibility_level:public_and_internal]
  end
  # rubocop:enable Layout/LineLength

  with_them do
    let(:project_ids) { projects.eql?(:any) ? projects : projects.map(&:id) }
    let(:group_ids) { groups.map(&:id) }

    let(:base_options) do
      {
        current_user: user,
        project_ids: project_ids,
        group_ids: group_ids,
        search_level: search_level
      }
    end

    let(:query) { 'foo' }
    let(:options) { base_options }

    subject(:build) { described_class.build(query: query, options: options) }

    it 'contains all expected filters' do
      assert_names_in_query(build,
        with: %w[project:multi_match_phrase:search_terms
          project:multi_match:and:search_terms
          filters:doc:is_a:project
          filters:non_archived],
        without: %w[project:match:search_terms])
    end

    context 'when advanced search syntax is used' do
      let(:query) { '*' }

      it 'contains all expected filters' do
        assert_names_in_query(build,
          with: %w[project:match:search_terms
            filters:doc:is_a:project
            filters:non_archived],
          without: %w[project:multi_match_phrase:search_terms
            project:multi_match:and:search_terms])
      end
    end

    describe 'filters' do
      it_behaves_like 'a query filtered by archived'

      describe 'authorization' do
        it 'applies authorization filters' do
          # emulate admin
          allow(user).to receive(:can_read_all_resources?).and_return(admin_mode_enabled)

          assert_names_in_query(build, with: expected_filter)
        end
      end
    end

    describe 'formats' do
      it_behaves_like 'a query that sets source_fields'
      it_behaves_like 'a query formatted for size'
    end
  end
end
