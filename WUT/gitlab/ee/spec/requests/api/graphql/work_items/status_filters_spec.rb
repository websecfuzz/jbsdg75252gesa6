# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Status filters', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:group_label) { create(:group_label, group: group) }
  let(:board) { create(:board, resource_parent: resource_parent) }
  let(:label_list) { create(:list, board: board, label: group_label) }

  let_it_be(:work_item_1) { create(:work_item, :issue, project: project, labels: [group_label]) }
  let_it_be(:work_item_2) { create(:work_item, :task, project: project, labels: [group_label]) }
  let_it_be(:work_item_3) { create(:work_item, :task, project: project, labels: [group_label]) }
  let_it_be(:work_item_4) { create(:work_item, :task, project: project, labels: [group_label]) }

  let(:current_user) { create(:user, guest_of: group) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'a filtered list' do
    it 'filters by status argument' do
      post_graphql(query, current_user: current_user)

      model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

      expect(model_ids.size).to eq(3)
      expect(model_ids).to contain_exactly(work_item_1.id, work_item_2.id, work_item_3.id)
    end
  end

  shared_examples 'an unfiltered list' do
    it 'does not filter by status argument' do
      post_graphql(query, current_user: current_user)

      model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

      expect(model_ids.size).to eq(4)
      expect(model_ids).to contain_exactly(work_item_1.id, work_item_2.id, work_item_3.id, work_item_4.id)
    end
  end

  shared_examples 'supports filtering by status ID' do
    let(:params) { { status: { id: status.to_global_id } } }

    context 'when filtering by valid ID' do
      it_behaves_like 'a filtered list'
    end

    context 'when filtering by invalid ID' do
      let(:params) { { status: { id: "gid://gitlab/WorkItems::Statuses::SystemDefined::Status/999" } } }

      it 'returns an error' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to contain_exactly(
          hash_including('message' => "System-defined status doesn't exist.")
        )
      end
    end

    context 'when work_item_status_feature_flag feature flag is disabled' do
      before do
        stub_feature_flags(work_item_status_feature_flag: false)
      end

      it_behaves_like 'an unfiltered list'
    end

    context 'when status param is not given' do
      let(:params) { {} }

      it_behaves_like 'an unfiltered list'
    end
  end

  shared_examples 'supports filtering by status name' do
    let(:params) { { status: { name: status.name } } }

    context 'when filtering by valid name' do
      it_behaves_like 'a filtered list'
    end

    context 'when filtering by invalid name' do
      let(:params) { { status: { name: 'invalid' } } }

      it 'returns an empty result' do
        post_graphql(query, current_user: current_user)

        expect_graphql_errors_to_be_empty

        model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

        expect(model_ids).to be_empty
      end
    end

    context 'when work_item_status_feature_flag feature flag is disabled' do
      before do
        stub_feature_flags(work_item_status_feature_flag: false)
      end

      it_behaves_like 'an unfiltered list'
    end
  end

  shared_examples 'does not support filtering by both status ID and name' do
    let(:params) { { status: { id: status.to_global_id, name: status.name } } }

    it 'returns an error' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to contain_exactly(
        hash_including('message' => 'Only one of [id, name] arguments is allowed at the same time.')
      )
    end
  end

  shared_examples 'filtering by status' do
    context 'for work items' do
      let(:query) do
        graphql_query_for(resource_parent.class.name.downcase, { full_path: resource_parent.full_path },
          query_nodes(:work_items, :id, args: params)
        )
      end

      let(:items) { graphql_data.dig(resource_parent.class.name.downcase, 'workItems', 'nodes') }

      context 'when querying group.workItems' do
        let_it_be(:resource_parent) { group }

        before do
          params[:include_descendants] = true
        end

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end

      context 'when querying project.workItems' do
        let_it_be(:resource_parent) { project }

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end
    end

    # Temporarily legacy issues need to be filterable by status for
    # the legacy issue list and legacy issue boards.
    context 'for issue lists' do
      let(:query) do
        graphql_query_for(resource_parent.class.name.downcase, { full_path: resource_parent.full_path },
          query_nodes(:issues, :id, args: params)
        )
      end

      let(:items) { graphql_data.dig(resource_parent.class.name.downcase, 'issues', 'nodes') }

      context 'when querying group.issues' do
        let_it_be(:resource_parent) { group }

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end

      context 'when querying project.issues' do
        let_it_be(:resource_parent) { project }

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end
    end

    context 'for issue boards' do
      let(:query) do
        graphql_query_for(resource_parent.class.name.downcase, { full_path: resource_parent.full_path },
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
        graphql_data.dig(resource_parent.class.name.downcase, 'boards', 'nodes')[0]
          .dig('lists', 'nodes')[0]
          .dig('issues', 'nodes')
      end

      context 'when querying group.board.lists.issues' do
        let_it_be(:resource_parent) { group }

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end

      context 'when querying project.board.lists.issues' do
        let_it_be(:resource_parent) { project }

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end
    end
  end

  context 'with system defined statuses' do
    let_it_be(:current_status_1) { create(:work_item_current_status, work_item: work_item_1) }
    let_it_be(:current_status_2) { create(:work_item_current_status, work_item: work_item_2) }
    let_it_be(:current_status_4) do
      create(:work_item_current_status, work_item: work_item_4, system_defined_status_id: 2)
    end

    let_it_be(:status) { build(:work_item_system_defined_status, :to_do) }

    it_behaves_like 'filtering by status'
  end

  context 'with custom statuses' do
    let_it_be(:current_status_1) { create(:work_item_current_status, work_item: work_item_1) }

    let_it_be(:lifecycle) do
      create(:work_item_custom_lifecycle, namespace: group).tap do |lifecycle|
        # Skip validations so that we can skip the license check.
        # We can't stub licensed features for let_it_be blocks.
        build(:work_item_type_custom_lifecycle,
          namespace: group,
          work_item_type: create(:work_item_type, :issue),
          lifecycle: lifecycle
        ).save!(validate: false)

        build(:work_item_type_custom_lifecycle,
          namespace: group,
          work_item_type: create(:work_item_type, :task),
          lifecycle: lifecycle
        ).save!(validate: false)
      end
    end

    let_it_be(:status) { lifecycle.default_open_status }

    let_it_be(:current_status_2) do
      create(:work_item_current_status, :custom, work_item: work_item_2, custom_status: status)
    end

    let_it_be(:current_status_4) do
      create(:work_item_current_status, :custom, work_item: work_item_4, custom_status: lifecycle.default_closed_status)
    end

    it_behaves_like 'filtering by status'
  end
end
