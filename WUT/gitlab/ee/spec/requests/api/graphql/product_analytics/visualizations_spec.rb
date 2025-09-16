# frozen_string_literal: true

require 'spec_helper'
require 'rspec-parameterized'

RSpec.describe 'Query.project(id).dashboards.panels(id).visualization', feature_category: :product_analytics do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :with_product_analytics_dashboard) }

  let(:query) do
    <<~GRAPHQL
      query {
        project(fullPath: "#{project.full_path}") {
          name
          customizableDashboards {
            nodes {
              title
              slug
              description
              panels {
                nodes {
                  title
                  gridAttributes
                  visualization {
                    type
                    options
                    data
                    errors
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL
  end

  before do
    stub_licensed_features(product_analytics: true, project_merge_request_analytics: false)
  end

  context 'when current user is a developer' do
    let_it_be(:user) { create(:user, developer_of: project) }

    it 'returns visualization' do
      get_graphql(query, current_user: user)

      expect(
        graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :panels, :nodes, 0, :visualization, :type)
      ).to eq('LineChart')
    end

    context 'when clickhouse is enabled' do
      using RSpec::Parameterized::TableSyntax

      before do
        allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
                      .with(user, :read_enterprise_ai_analytics, anything)
                      .and_return(true)
      end

      where(:node_idx, :panel_type, :panel_title) do
        0 | 'SingleStat' | 'Assigned Duo seat engagement'
        1 | 'SingleStat' | 'Code Suggestions: Usage'
        2 | 'SingleStat' | 'Code Suggestions: Acceptance rate'
        3 | 'SingleStat' | 'Duo Chat: Usage'
        4 | 'AiImpactTable' | 'Lifecycle metrics for the %{namespaceName} %{namespaceType}'
        5 | 'AiImpactTable' | 'AI usage metrics for the %{namespaceName} %{namespaceType}'
      end

      with_them do
        it "returns the each visualization" do
          get_graphql(query, current_user: user)

          expect(
            graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :panels, :nodes, node_idx, :visualization,
              :type)
          ).to eq(panel_type)
          expect(
            graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :panels, :nodes, node_idx, :title)
          ).to eq(panel_title)
        end
      end
    end

    context 'when the visualization has validation errors' do
      let_it_be(:project) { create(:project, :with_product_analytics_invalid_custom_visualization) }
      let_it_be(:user) { create(:user, developer_of: project) }

      let(:slug) { "dashboard_example_invalid_vis" }
      let(:query) do
        <<~GRAPHQL
          query {
            project(fullPath: "#{project.full_path}") {
              customizableDashboards(slug: "#{slug}") {
                nodes {
                  panels {
                    nodes {
                      visualization {
                        errors
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      it 'returns the visualization with a validation error' do
        get_graphql(query, current_user: user)

        expect(
          graphql_data_at(:project, :customizable_dashboards, :nodes, 0,
            :panels, :nodes, 0, :visualization, :errors, 0))
          .to eq("property '/type' is not one of: " \
                 "[\"AreaChart\", \"LineChart\", \"ColumnChart\", \"DataTable\", \"SingleStat\", " \
                 "\"DORAChart\", \"UsageOverview\", \"DoraPerformersScore\", " \
                 "\"DoraProjectsComparison\", \"AiImpactTable\", \"ContributionsByUserTable\", " \
                 "\"ContributionsPushesChart\", \"ContributionsIssuesChart\", " \
                   "\"ContributionsMergeRequestsChart\", \"NamespaceMetadata\", \"MergeRequestsThroughputTable\"]")
      end
    end
  end
end
