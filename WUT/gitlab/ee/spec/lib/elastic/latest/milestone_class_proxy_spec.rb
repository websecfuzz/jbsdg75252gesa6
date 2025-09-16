# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::MilestoneClassProxy, :elastic, :sidekiq_inline, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  subject(:proxy) { described_class.new(Milestone, use_separate_indices: false) }

  describe '#elastic_search' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:query) { 'Foo' }
    let_it_be(:current_user) { create(:user) }
    let(:options) { { current_user: current_user, project_ids: [project.id] } }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :public, group: group) }
    let_it_be(:project_milestone) { create(:milestone, project: project, title: 'Foo') }
    let_it_be(:group_milestone) { create(:milestone, group: group, title: 'Foo Bar') }

    let(:result) { proxy.elastic_search(query, options: options) }

    before do
      Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
      ensure_elasticsearch_index!
    end

    where(:search_level, :projects, :groups, :public_and_internal_projects) do
      'global'  | :any            | []            | true
      'global'  | :any            | []            | false
      'group'   | :any            | [ref(:group)] | true
      'group'   | :any            | [ref(:group)] | false
      'group'   | []              | [ref(:group)] | true
      'group'   | []              | [ref(:group)] | false
      'project' | :any            | []            | true
      'project' | :any            | []            | false
      'project' | [ref(:project)] | []            | true
      'project' | [ref(:project)] | []            | false
      'project' | [ref(:project)] | [ref(:group)] | true
      'project' | [ref(:project)] | [ref(:group)] | false
    end

    with_them do
      let(:project_ids) { projects.eql?(:any) ? projects : projects.map(&:id) }
      let(:group_ids) { groups.map(&:id) }

      let(:options) do
        {
          current_user: current_user,
          search_level: search_level,
          project_ids: project_ids,
          group_ids: group_ids,
          public_and_internal_projects: public_and_internal_projects,
          order_by: nil,
          sort: nil
        }
      end

      it 'has the correct named queries' do
        result.response

        expected_queries = %w[
          milestone:multi_match:and:search_terms
          milestone:multi_match_phrase:search_terms
          filters:project
          filters:doc:is_a:milestone
        ]

        expected_queries.concat(%w[filters:non_archived]) if search_level != 'project'

        if projects == :any
          any_filter = %w[
            filters:project:any
            filters:project:issues:enabled_or_private
            filters:project:merge_requests:enabled_or_private
          ]

          expected_queries.concat(any_filter)
        else
          expected_queries.concat(%w[filters:project])
        end

        if public_and_internal_projects
          visibility_filters = %w[filters:project:visibility:10
            filters:project:visibility:20
            filters:project:visibility:10:issues:access_level:enabled
            filters:project:visibility:20:issues:access_level:enabled
            filters:project:visibility:10:merge_requests:access_level:enabled
            filters:project:visibility:20:merge_requests:access_level:enabled]

          expected_queries.concat(visibility_filters)
        end

        assert_named_queries(
          *expected_queries
        )
      end

      context 'when advanced search syntax is used in the query' do
        let_it_be(:query) { 'Foo*' }

        it 'has the correct named queries' do
          result.response

          expected_queries = %w[milestone:match:search_terms
            filters:project
            filters:doc:is_a:milestone]

          expected_queries.concat(%w[filters:non_archived]) if search_level != 'project'

          if projects == :any
            any_filter = %w[
              filters:project:any
              filters:project:issues:enabled_or_private
              filters:project:merge_requests:enabled_or_private
            ]

            expected_queries.concat(any_filter)
          else
            expected_queries.concat(%w[filters:project])
          end

          if public_and_internal_projects
            visibility_filters = %w[filters:project:visibility:10
              filters:project:visibility:20
              filters:project:visibility:10:issues:access_level:enabled
              filters:project:visibility:20:issues:access_level:enabled
              filters:project:visibility:10:merge_requests:access_level:enabled
              filters:project:visibility:20:merge_requests:access_level:enabled]

            expected_queries.concat(visibility_filters)
          end

          assert_named_queries(
            *expected_queries
          )
        end
      end
    end
  end
end
