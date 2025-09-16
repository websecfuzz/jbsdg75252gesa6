# frozen_string_literal: true

RSpec.shared_examples 'graphql work item type list request spec EE' do
  include GraphqlHelpers

  let(:parent_key) { parent.to_ability_name.to_sym }
  let(:licensed_features) { WorkItems::Type::LICENSED_WIDGETS.keys }
  let(:disabled_features) { [] }
  let(:work_item_type_fields) { 'name widgetDefinitions { type }' }
  let(:returned_widgets) do
    graphql_data_at(parent_key.to_s, 'workItemTypes', 'nodes').flat_map do |type|
      type['widgetDefinitions'].pluck('type')
    end.uniq
  end

  let(:query) do
    graphql_query_for(
      parent_key.to_s,
      { 'fullPath' => parent.full_path },
      query_nodes('WorkItemTypes', work_item_type_fields)
    )
  end

  describe 'allowed statuses' do
    include_context 'with work item types request context EE'

    let(:work_item_types) { graphql_data_at(parent_key, :workItemTypes, :nodes) }
    let_it_be(:names_of_system_defined_statuses) do
      ::WorkItems::Statuses::SystemDefined::Status.all.map(&:name)
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      context 'with system-defined statuses' do
        it 'returns system-defined statuses for supported work item types' do
          post_graphql(query, current_user: current_user)

          work_item_types.each do |work_item_type|
            status_widgets = work_item_type['widgetDefinitions'].select { |widget| widget['type'] == 'STATUS' }

            status_widgets.each do |widget|
              if status_widget_supported?(work_item_type['name'])
                allowed_statuses = widget['allowedStatuses']
                status_names = allowed_statuses.pluck('name')
                default_open_status_name = widget.dig('defaultOpenStatus', 'name')
                default_closed_status_name = widget.dig('defaultClosedStatus', 'name')

                expect(allowed_statuses).to all(include('id', 'name', 'iconName', 'color', 'position'))
                expect(status_names).to match_array(names_of_system_defined_statuses)
                expect(default_open_status_name).to eq('To do')
                expect(default_closed_status_name).to eq('Done')
              else
                expect(widget['allowedStatuses']).to be_empty
                expect(widget.dig('defaultOpenStatus', 'name')).to be_empty
                expect(widget.dig('defaultClosedStatus', 'name')).to be_empty
              end
            end
          end
        end

        context 'with work_item_status_feature_flag disabled' do
          before do
            stub_feature_flags(work_item_status_feature_flag: false)
            post_graphql(query, current_user: current_user)
          end

          it 'does not return status widget' do
            status_widgets = extract_status_widgets

            expect(status_widgets).to be_empty
          end
        end
      end

      context 'with custom statuses' do
        let(:root_namespace) { parent.resource_parent&.root_ancestor }
        let(:open_status) { create(:work_item_custom_status, :open, namespace: root_namespace) }
        let(:closed_status) { create(:work_item_custom_status, :closed, namespace: root_namespace) }
        let(:duplicate_status) { create(:work_item_custom_status, :duplicate, namespace: root_namespace) }

        let(:lifecycle) do
          create(:work_item_custom_lifecycle,
            namespace: root_namespace,
            default_open_status: open_status,
            default_closed_status: closed_status,
            default_duplicate_status: duplicate_status
          )
        end

        let(:supported_item_types) { [create(:work_item_type, :task), create(:work_item_type, :issue)] }

        let(:type_custom_lifecycles) do
          supported_item_types.filter_map do |work_item_type|
            if status_widget_supported?(work_item_type.name)
              create(:work_item_type_custom_lifecycle,
                lifecycle: lifecycle,
                work_item_type: work_item_type,
                namespace: root_namespace)
            end
          end
        end

        it 'returns custom statuses for supported work item types' do
          skip "No work item types support status widget" if type_custom_lifecycles.empty?

          post_graphql(query, current_user: current_user)

          expected_names = [
            open_status.name,
            closed_status.name,
            duplicate_status.name
          ]

          work_item_types.each do |work_item_type|
            status_widgets = work_item_type['widgetDefinitions'].select { |widget| widget['type'] == 'STATUS' }

            status_widgets.each do |widget|
              allowed_statuses = widget['allowedStatuses']
              default_open_status_name = widget.dig('defaultOpenStatus', 'name')
              default_closed_status_name = widget.dig('defaultClosedStatus', 'name')

              expect(allowed_statuses).to all(include('id', 'name', 'iconName', 'color', 'position'))
              expect(allowed_statuses.pluck('name')).to match_array(expected_names)
              expect(default_open_status_name).to eq(open_status.name)
              expect(default_closed_status_name).to eq(closed_status.name)
            end
          end
        end

        context 'with work_item_status_feature_flag disabled' do
          before do
            stub_feature_flags(work_item_status_feature_flag: false)
            post_graphql(query, current_user: current_user)
          end

          it 'does not return status widget' do
            status_widgets = extract_status_widgets

            expect(status_widgets).to be_empty
          end
        end
      end
    end

    context 'when feature is unlicensed' do
      before do
        stub_licensed_features(work_item_status: false)
        post_graphql(query, current_user: current_user)
      end

      it 'does not return status widget' do
        status_widgets = extract_status_widgets

        expect(status_widgets).to be_empty
      end
    end
  end

  describe 'licensed widgets' do
    before do
      stub_licensed_features(**feature_hash)
      post_graphql(query, current_user: current_user)
    end

    where(feature_widget: WorkItems::Type::LICENSED_WIDGETS.transform_values { |v| Array(v) }.to_a)

    with_them do
      let(:feature) { feature_widget.first }
      let(:widgets) { feature_widget.last }

      context 'when feature is available' do
        it 'returns the associated licensed widget' do
          widgets.each do |widget|
            next unless status_widget_available?(widget)

            expect(returned_widgets).to include(widget_to_enum_string(widget))
          end
        end
      end

      context 'when feature is not available' do
        let(:disabled_features) { [feature] }

        it 'does not return the unlincensed widgets' do
          post_graphql(query, current_user: developer)

          widgets.each do |widget|
            expect(returned_widgets).not_to include(widget_to_enum_string(widget))
          end
        end
      end
    end
  end

  def widget_to_enum_string(widget)
    widget.type.to_s.upcase
  end

  def feature_hash
    available_features = licensed_features - disabled_features

    available_features.index_with { |_| true }.merge(disabled_features.index_with { |_| false })
  end

  def extract_status_widgets
    work_item_types.flat_map do |work_item_type|
      work_item_type['widgetDefinitions'].select { |widget| widget['type'] == 'STATUS' }
    end
  end

  def status_widget_supported?(work_item_type_name)
    widget_available_for?(work_item_type_name: work_item_type_name, widget_type: 'status') &&
      parent&.resource_parent&.root_ancestor&.try(:work_item_status_feature_available?)
  end

  def status_widget_available?(widget)
    widget == WorkItems::Widgets::Status &&
      parent.resource_parent&.root_ancestor&.try(:work_item_status_feature_available?)
  end
end
