# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a list of work item types for a group EE', feature_category: :team_planning do
  let_it_be(:namespace) { create(:group, :private) }
  let_it_be(:developer) { create(:user, developer_of: namespace) }
  let(:parent) { namespace }
  let(:current_user) { developer }

  it_behaves_like 'graphql work item type list request spec', 'with work item types request context EE'

  it_behaves_like 'graphql work item type list request spec EE'

  context 'with custom fields widget' do
    include GraphqlHelpers

    include_context 'with group configured with custom fields'

    let(:query) do
      graphql_query_for('namespace', { 'fullPath' => group.full_path },
        query_nodes('WorkItemTypes', work_item_type_fields)
      )
    end

    let(:work_item_type_fields) do
      <<~GRAPHQL
        id
        widgetDefinitions {
          type
          ... on WorkItemWidgetDefinitionCustomFields {
            customFieldValues {
              customField {
                id
              }
            }
          }
        }
      GRAPHQL
    end

    before do
      stub_licensed_features(custom_fields: true)
    end

    it 'returns custom fields available for each work item type' do
      post_graphql(query, current_user: current_user)

      custom_field_widgets_per_type = graphql_data_at('namespace', 'workItemTypes', 'nodes').map do |type|
        {
          work_item_type_id: type['id'],
          custom_fields_widget: type['widgetDefinitions'].find { |widget| widget['type'] == 'CUSTOM_FIELDS' }
        }
      end

      expect(custom_field_widgets_per_type).to include(
        {
          work_item_type_id: issue_type.to_gid.to_s,
          custom_fields_widget: {
            'type' => 'CUSTOM_FIELDS',
            'customFieldValues' => [
              { 'customField' => { 'id' => select_field.to_gid.to_s } },
              { 'customField' => { 'id' => number_field.to_gid.to_s } },
              { 'customField' => { 'id' => text_field.to_gid.to_s } },
              { 'customField' => { 'id' => multi_select_field.to_gid.to_s } }
            ]
          }
        }
      )

      expect(custom_field_widgets_per_type).to include(
        {
          work_item_type_id: task_type.to_gid.to_s,
          custom_fields_widget: {
            'type' => 'CUSTOM_FIELDS',
            'customFieldValues' => [
              { 'customField' => { 'id' => select_field.to_gid.to_s } },
              { 'customField' => { 'id' => multi_select_field.to_gid.to_s } },
              { 'customField' => { 'id' => field_on_other_type.to_gid.to_s } }
            ]
          }
        }
      )
    end

    context 'when loading associated fields' do
      let(:work_item_type_fields) do
        <<~GRAPHQL
          id
          widgetDefinitions {
            type
            ... on WorkItemWidgetDefinitionCustomFields {
              customFieldValues {
                customField {
                  id
                  selectOptions { id }
                }
              }
            }
          }
        GRAPHQL
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        post_graphql(query, current_user: current_user)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end
        expect_graphql_errors_to_be_empty

        other_type = create(:work_item_type, :non_default)
        create(:widget_definition, widget_type: 'custom_fields', work_item_type: other_type)
        create(:custom_field, namespace: group, work_item_types: [other_type])

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
        expect_graphql_errors_to_be_empty

        issue_type_data = graphql_data_at(:namespace, :workItemTypes, :nodes).find do |t|
          t['id'] == issue_type.to_gid.to_s
        end
        custom_fields_widget = issue_type_data['widgetDefinitions'].find { |d| d['type'] == 'CUSTOM_FIELDS' }
        select_option_ids = custom_fields_widget['customFieldValues'].flat_map do |v|
          v.dig('customField', 'selectOptions').pluck('id')
        end

        expect(select_option_ids).to match_array([
          select_option_1,
          select_option_2,
          multi_select_option_1,
          multi_select_option_2,
          multi_select_option_3
        ].map { |o| o.to_global_id.to_s })
      end
    end
  end
end
