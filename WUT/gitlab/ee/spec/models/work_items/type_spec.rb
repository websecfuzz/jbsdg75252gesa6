# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Type, feature_category: :team_planning do
  describe '#widgets' do
    let_it_be(:group) { build_stubbed(:group) }
    let_it_be(:project) { build_stubbed(:project, group: group) }
    let_it_be_with_refind(:work_item_type) { create(:work_item_type) }
    let(:licensed_features) { WorkItems::Type::LICENSED_WIDGETS.keys }
    let(:disabled_features) { [] }

    before_all do
      # All possible default work item types already exist on the DB. So we find the first one, remove all existing
      # widgets and then add all existing ones. This type now has all possible widgets just for testing.
      WorkItems::WidgetDefinition.where(work_item_type: work_item_type).delete_all
      WorkItems::WidgetDefinition.widget_types.each_key do |type|
        create(:widget_definition, work_item_type: work_item_type, name: type.to_s, widget_type: type)
      end
    end

    shared_examples 'work_item_type returning only licensed widgets' do
      let(:feature) { feature_widget.first }
      let(:widget_classes) { feature_widget.last }

      subject(:returned_widgets) { work_item_type.widgets(parent) }

      context 'when feature is available' do
        it 'returns the associated licensesd widget' do
          widget_classes.each do |widget|
            expect(returned_widgets.map(&:widget_class)).to include(widget)
          end
        end
      end

      context 'when feature is not available' do
        let(:disabled_features) { [feature] }

        it 'does not return the unlincensed widgets' do
          widget_classes.each do |widget|
            expect(returned_widgets.map(&:widget_class)).not_to include(widget)
          end
        end
      end

      context 'when type is epic' do
        let_it_be_with_refind(:work_item_type) { create(:work_item_type, :epic) }

        it 'returns Assignees widget' do
          expect(returned_widgets.map(&:widget_class)).to include(::WorkItems::Widgets::Assignees)
        end

        it 'returns Milestone widget' do
          expect(returned_widgets.map(&:widget_class)).to include(::WorkItems::Widgets::Milestone)
        end
      end

      context 'when work_item_status_feature_flag is disabled?' do
        before do
          stub_feature_flags(work_item_status_feature_flag: false)
        end

        it 'does not return status widget' do
          expect(returned_widgets.map(&:widget_class)).not_to include(::WorkItems::Widgets::Status)
        end
      end
    end

    where(feature_widget: WorkItems::Type::LICENSED_WIDGETS.transform_values { |v| Array(v) }.to_a)

    with_them do
      before do
        stub_licensed_features(**feature_hash)
      end

      context 'when parent is a group' do
        let(:parent) { group }

        it_behaves_like 'work_item_type returning only licensed widgets'
      end

      context 'when parent is a project' do
        let(:parent) { project }

        it_behaves_like 'work_item_type returning only licensed widgets'
      end

      context 'when parent is a project in user_namespace' do
        let(:parent) { create(:project) }
        let(:feature) { feature_widget.first }
        let(:widget_classes) { WorkItems::Type::EXCLUDED_USER_NAMESPACE_LICENSED_WIDGETS }

        subject(:returned_widgets) { work_item_type.widgets(parent) }

        it 'does not return the widgets excluded in user namespace' do
          widget_classes.each do |widget|
            expect(returned_widgets.map(&:widget_class)).not_to include(widget)
          end
        end
      end
    end
  end

  describe '.allowed_group_level_types' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_group) }

    subject { described_class.allowed_group_level_types(group) }

    context 'when epic license is available' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'returns supported types at group level' do
        is_expected.to contain_exactly(*described_class.base_types.keys)
      end

      context 'when create_group_level_work_items is disabled' do
        before do
          stub_feature_flags(create_group_level_work_items: false)
        end

        it { is_expected.to contain_exactly('epic') }
      end

      context 'when create_group_level_work_items is enabled' do
        before do
          stub_feature_flags(create_group_level_work_items: true)
        end

        it { is_expected.to contain_exactly(*described_class.base_types.keys).and include('epic') }
      end
    end

    context 'when epic license is not available' do
      before do
        stub_licensed_features(epics: false)
      end

      it { is_expected.to contain_exactly(*described_class.base_types.keys.excluding('epic')) }

      context 'when create_group_level_work_items is disabled' do
        before do
          stub_feature_flags(create_group_level_work_items: false)
        end

        it { is_expected.to be_empty }
      end
    end
  end

  describe '#supported_conversion_types' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:resource_parent) { create(:project, group: root_group) }
    let_it_be(:issue_type) { create(:work_item_type, :issue) }
    let(:work_item_type) { issue_type }
    let_it_be(:developer_user) { create(:user) }
    let_it_be(:guest_user) { create(:user) }

    before_all do
      resource_parent.add_guest(guest_user)
      resource_parent.add_developer(developer_user)
    end

    shared_examples 'licensed type availability' do |type, licensed_feature|
      let_it_be(:wi_type) { create(:work_item_type, type.to_sym) }

      context "when #{licensed_feature} is available" do
        before do
          stub_licensed_features(licensed_feature => true)
          allow(Ability).to receive(:allowed?).with(developer_user, :create_epic,
            resource_parent.group).and_return(true)
        end

        it "returns #{type} type in the supported types" do
          expect(work_item_type.supported_conversion_types(resource_parent, developer_user)).to include(wi_type)
        end
      end

      context "when #{licensed_feature} is unavailable" do
        before do
          stub_licensed_features(licensed_feature => false)
        end

        it "does not return #{type} type in the supported types" do
          expect(work_item_type.supported_conversion_types(resource_parent, developer_user)).not_to include(wi_type)
        end
      end
    end

    shared_examples 'okrs types not included' do
      it 'does not return Objective and Key Result types in the supported types' do
        expect(work_item_type.supported_conversion_types(resource_parent, developer_user))
          .not_to include(objective, key_result)
      end
    end

    WorkItems::Type::LICENSED_TYPES.each do |type, licensed_feature|
      it_behaves_like 'licensed type availability', type, licensed_feature
    end

    context 'when okrs_mvc is disabled' do
      let_it_be(:objective) { create(:work_item_type, :objective) }
      let_it_be(:key_result) { create(:work_item_type, :key_result) }

      before do
        stub_feature_flags(okrs_mvc: false)
      end

      it_behaves_like 'okrs types not included'

      context 'when resource parent is group' do
        let_it_be(:resource_parent) { resource_parent.reload.project_namespace }

        it_behaves_like 'okrs types not included'
      end
    end

    context 'when epics are licensed' do
      let_it_be(:epic) { create(:work_item_type, :epic) }

      before do
        stub_licensed_features(epics: true)
      end

      it "does not return epic type in the supported types" do
        expect(work_item_type.supported_conversion_types(resource_parent, developer_user)).not_to include(epic)
      end
    end

    context 'when user does not have permission' do
      let_it_be(:epic) { create(:work_item_type, :epic) }

      before do
        stub_licensed_features(epics: true)
        allow(Ability).to receive(:allowed?).with(guest_user, :create_epic,
          resource_parent.group).and_return(false)
      end

      it "does not return epic type in the supported types" do
        expect(work_item_type.supported_conversion_types(resource_parent, guest_user)).not_to include(epic)
      end
    end
  end

  describe '#allowed_child_types' do
    let_it_be(:resource_parent) { create(:project) }
    let_it_be(:issue_type) { described_class.find_by_name('Issue') }
    let_it_be(:epic_type) { described_class.find_by_name('Epic') }
    let_it_be(:task_type) { described_class.find_by_name('Task') }

    subject { parent_type.allowed_child_types(authorize: authorized, resource_parent: resource_parent) }

    shared_examples 'allowed child types' do
      context 'when license authorization is required' do
        let(:authorized) { true }

        before do
          stub_licensed_features(features)
        end

        it 'checks if licensed features are available for the child type' do
          is_expected.to match_array(expected_child_types)
        end
      end

      context 'when license authorization is not required' do
        let(:authorized) { false }

        it 'does not check for license availability' do
          is_expected.to match_array(all_child_types)
        end
      end
    end

    context 'when parent type has licensed child types' do
      let(:parent_type) { epic_type }
      let(:all_child_types) { [epic_type, issue_type] }

      it_behaves_like 'allowed child types' do
        let(:features) { { epics: true, subepics: true } }
        let(:expected_child_types) { [epic_type, issue_type] }
      end

      it_behaves_like 'allowed child types' do
        let(:features) { { epics: false, subepics: true } }
        let(:expected_child_types) { [epic_type] }
      end

      it_behaves_like 'allowed child types' do
        let(:parent_type) { epic_type }
        let(:features) { { epics: true, subepics: false } }
        let(:expected_child_types) { [issue_type] }
      end

      it_behaves_like 'allowed child types' do
        let(:features) { { epics: false, subepics: false } }
        let(:expected_child_types) { [] }
      end
    end

    context 'when parent type does not have licensed child types' do
      let(:parent_type) { issue_type }
      let(:all_child_types) { [task_type] }

      it_behaves_like 'allowed child types' do
        let(:features) { {} }
        let(:expected_child_types) { all_child_types }
      end
    end
  end

  describe '#allowed_parent_types' do
    let_it_be(:resource_parent) { create(:project) }
    let_it_be(:issue_type) { described_class.find_by_name('Issue') }
    let_it_be(:epic_type) { described_class.find_by_name('Epic') }
    let_it_be(:task_type) { described_class.find_by_name('Task') }

    subject { child_type.allowed_parent_types(authorize: authorized, resource_parent: resource_parent) }

    shared_examples 'allowed parent types' do
      context 'when license authorization is required' do
        let(:authorized) { true }

        before do
          stub_licensed_features(feature)
        end

        it 'checks if licensed features are available for the parent type' do
          is_expected.to match_array(expected_parent_types)
        end
      end

      context 'when license authorization is not required' do
        let(:authorized) { false }

        it 'does not check for license availability' do
          is_expected.to match_array(supported_parent_types)
        end
      end
    end

    context 'when child type has a licensed parent type' do
      context 'when child type is issue' do
        let(:child_type) { issue_type }
        let(:supported_parent_types) { [epic_type] }

        it_behaves_like 'allowed parent types' do
          let(:feature) { { epics: true } }
          let(:expected_parent_types) { supported_parent_types }
        end

        it_behaves_like 'allowed parent types' do
          let(:feature) { { epics: false } }
          let(:expected_parent_types) { [] }
        end
      end

      context 'when child type is epic' do
        let(:child_type) { epic_type }
        let(:supported_parent_types) { [epic_type] }

        it_behaves_like 'allowed parent types' do
          let(:feature) { { subepics: true } }
          let(:expected_parent_types) { supported_parent_types }
        end

        it_behaves_like 'allowed parent types' do
          let(:feature) { { subepics: false } }
          let(:expected_parent_types) { [] }
        end
      end
    end

    context 'when child type does not have a licensed parent type' do
      let(:child_type) { task_type }
      let(:supported_parent_types) do
        [described_class.find_by_name('Incident'), issue_type, described_class.find_by_name('Ticket')]
      end

      it_behaves_like 'allowed parent types' do
        let(:feature) { {} }
        let(:expected_parent_types) { supported_parent_types }
      end
    end
  end

  describe '#custom_status_enabled_for?' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:work_item_type) { create(:work_item_type, :task) }

    subject { work_item_type.custom_status_enabled_for?(namespace.id) }

    before do
      stub_licensed_features(work_item_status: true)
    end

    context 'when custom status is enabled for the type in the namespace' do
      before do
        create(:work_item_type_custom_lifecycle,
          work_item_type: work_item_type,
          namespace: namespace
        )
      end

      it { is_expected.to be_truthy }
    end

    context 'when custom status is not enabled for the type in the namespace' do
      it { is_expected.to be_falsey }
    end

    context 'when namespace_id is nil' do
      subject { work_item_type.custom_status_enabled_for?(nil) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#custom_lifecycle_for' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:work_item_type) { create(:work_item_type, :task) }

    subject(:custom_lifecycle_result) { work_item_type.custom_lifecycle_for(namespace.id) }

    before do
      stub_licensed_features(work_item_status: true)
    end

    context 'when custom lifecycle exists for the type and namespace' do
      let_it_be(:lifecycle) do
        create(:work_item_custom_lifecycle, namespace: namespace)
      end

      before do
        create(:work_item_type_custom_lifecycle, namespace: namespace, work_item_type: work_item_type,
          lifecycle: lifecycle)
      end

      it 'returns the lifecycle' do
        expect(custom_lifecycle_result).to eq(lifecycle)
      end
    end

    context 'when no custom lifecycle exists for the type and namespace' do
      it 'returns nil' do
        expect(custom_lifecycle_result).to be_nil
      end
    end

    context 'when namespace_id is nil' do
      subject(:custom_lifecycle_result) { work_item_type.custom_lifecycle_for(nil) }

      it 'returns nil' do
        expect(custom_lifecycle_result).to be_nil
      end
    end
  end

  def feature_hash
    available_features = licensed_features - disabled_features

    available_features.index_with { |_| true }.merge(disabled_features.index_with { |_| false })
  end
end
