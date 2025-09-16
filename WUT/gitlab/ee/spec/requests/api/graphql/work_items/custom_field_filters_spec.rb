# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Custom field filters', feature_category: :team_planning do
  include GraphqlHelpers

  include_context 'with group configured with custom fields'

  let_it_be(:group_label) { create(:group_label, group: group) }

  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:work_item_a) { create(:work_item, project: project, labels: [group_label]) }
  let_it_be(:work_item_b) { create(:work_item, project: project, labels: [group_label]) }
  let_it_be(:work_item_c) { create(:work_item, project: project, labels: [group_label]) }

  let(:current_user) { create(:user, guest_of: group) }
  let(:params) do
    {
      custom_field: [
        {
          custom_field_id: select_field.to_global_id.to_s,
          selected_option_ids: [
            select_option_2.to_global_id.to_s
          ]
        }
      ]
    }
  end

  before_all do
    create(:work_item_select_field_value, work_item_id: work_item_a.id, custom_field: select_field,
      custom_field_select_option: select_option_1)
    create(:work_item_select_field_value, work_item_id: work_item_b.id, custom_field: select_field,
      custom_field_select_option: select_option_2)
    create(:work_item_select_field_value, work_item_id: work_item_c.id, custom_field: select_field,
      custom_field_select_option: select_option_2)
  end

  before do
    stub_licensed_features(custom_fields: true)
  end

  shared_examples 'returns filtered counts' do
    it 'returns counts matching the custom field filter' do
      post_graphql(query, current_user: current_user)

      expect(count).to eq(2)
    end
  end

  shared_examples 'returns filtered items' do
    it 'returns items matching the custom field filter' do
      post_graphql(query, current_user: current_user)

      model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

      expect(model_ids.size).to eq(2)
      expect(model_ids).to contain_exactly(work_item_b.id, work_item_c.id)
    end
  end

  context 'when querying project.issueStatusCounts' do
    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_graphql_field(:issueStatusCounts, params, :opened)
      )
    end

    let(:count) { graphql_data.dig('project', 'issueStatusCounts', 'opened') }

    it_behaves_like 'returns filtered counts'
  end

  context 'when querying project.issues' do
    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_nodes(:issues, :id, args: params)
      )
    end

    let(:items) { graphql_data.dig('project', 'issues', 'nodes') }

    it_behaves_like 'returns filtered items'
  end

  context 'when querying group.issues' do
    let(:query) do
      graphql_query_for(:group, { full_path: group.full_path },
        query_nodes(:issues, :id, args: params)
      )
    end

    let(:items) { graphql_data.dig('group', 'issues', 'nodes') }

    it_behaves_like 'returns filtered items'
  end

  context 'when querying project.workItemStateCounts' do
    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_graphql_field(:workItemStateCounts, params, :opened)
      )
    end

    let(:count) { graphql_data.dig('project', 'workItemStateCounts', 'opened') }

    it_behaves_like 'returns filtered counts'
  end

  context 'when querying group.workItemStateCounts' do
    let(:query) do
      graphql_query_for(:group, { full_path: group.full_path },
        query_graphql_field(:workItemStateCounts, params.merge(include_descendants: true), :opened)
      )
    end

    let(:count) { graphql_data.dig('group', 'workItemStateCounts', 'opened') }

    it_behaves_like 'returns filtered counts'
  end

  context 'when querying project.workItems' do
    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        query_nodes(:work_items, :id, args: params)
      )
    end

    let(:items) { graphql_data.dig('project', 'workItems', 'nodes') }

    it_behaves_like 'returns filtered items'
  end

  context 'when querying group.workItems' do
    let(:query) do
      graphql_query_for(:group, { full_path: group.full_path },
        query_nodes(:work_items, :id, args: params.merge(include_descendants: true))
      )
    end

    let(:items) { graphql_data.dig('group', 'workItems', 'nodes') }

    it_behaves_like 'returns filtered items'
  end

  context 'when querying project.board.lists.issues' do
    let_it_be(:board) { create(:board, resource_parent: project) }
    let_it_be(:label_list) { create(:list, board: board, label: group_label) }

    let(:query) do
      graphql_query_for(:project, { full_path: project.full_path },
        <<~BOARDS
          boards(first: 1) {
            nodes {
              lists(id: "#{label_list.to_global_id}") {
                nodes {
                  issues(#{attributes_to_graphql(filters: params)}) {
                    nodes {
                      id
                    }
                  }
                }
              }
            }
          }
        BOARDS
      )
    end

    let(:items) do
      graphql_data.dig('project', 'boards', 'nodes')[0]
        .dig('lists', 'nodes')[0]
        .dig('issues', 'nodes')
    end

    it_behaves_like 'returns filtered items'
  end

  context 'when querying group.board.lists.issues' do
    let_it_be(:board) { create(:board, resource_parent: group) }
    let_it_be(:label_list) { create(:list, board: board, label: group_label) }

    let(:query) do
      graphql_query_for(:group, { full_path: group.full_path },
        <<~BOARDS
          boards(first: 1) {
            nodes {
              lists(id: "#{label_list.to_global_id}") {
                nodes {
                  issues(#{attributes_to_graphql(filters: params)}) {
                    nodes {
                      id
                    }
                  }
                }
              }
            }
          }
        BOARDS
      )
    end

    let(:items) do
      graphql_data.dig('group', 'boards', 'nodes')[0]
        .dig('lists', 'nodes')[0]
        .dig('issues', 'nodes')
    end

    it_behaves_like 'returns filtered items'
  end

  context 'with legacy epics' do
    let_it_be(:work_item_a) { create(:epic, group: group, labels: [group_label]) }
    let_it_be(:work_item_b) { create(:epic, group: group, labels: [group_label]) }
    let_it_be(:work_item_c) { create(:epic, group: group, labels: [group_label]) }

    before_all do
      create(:work_item_select_field_value, work_item_id: work_item_a.issue_id, custom_field: select_field,
        custom_field_select_option: select_option_1)
      create(:work_item_select_field_value, work_item_id: work_item_b.issue_id, custom_field: select_field,
        custom_field_select_option: select_option_2)
      create(:work_item_select_field_value, work_item_id: work_item_c.issue_id, custom_field: select_field,
        custom_field_select_option: select_option_2)
    end

    before do
      stub_licensed_features(epics: true, custom_fields: true)
    end

    context 'when querying group.epics' do
      let(:query) do
        graphql_query_for(:group, { full_path: group.full_path },
          query_nodes(:epics, :id, args: params)
        )
      end

      let(:items) { graphql_data.dig('group', 'epics', 'nodes') }

      it_behaves_like 'returns filtered items'
    end

    context 'when querying group.epicBoards.lists.epics' do
      let_it_be(:board) { create(:epic_board, group: group) }
      let_it_be(:label_list) { create(:epic_list, epic_board: board, label: group_label) }

      let(:query) do
        graphql_query_for(:group, { full_path: group.full_path },
          <<~BOARDS
            epicBoards(first: 1) {
              nodes {
                lists(id: "#{label_list.to_global_id}") {
                  nodes {
                    epics(#{attributes_to_graphql(filters: params)}) {
                      nodes {
                        id
                      }
                    }
                  }
                }
              }
            }
          BOARDS
        )
      end

      let(:items) do
        graphql_data.dig(
          'group', 'epicBoards', 'nodes', 0,
          'lists', 'nodes', 0,
          'epics', 'nodes'
        )
      end

      it_behaves_like 'returns filtered items'
    end
  end
end
