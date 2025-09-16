# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItem, :elastic_helpers, feature_category: :team_planning do
  let_it_be(:reusable_project) { create(:project) }
  let_it_be(:reusable_group) { create(:group) }
  let_it_be(:user) { create(:user) }

  it 'has one `color`' do
    is_expected.to have_one(:color)
      .class_name('WorkItems::Color')
      .with_foreign_key('issue_id')
      .inverse_of(:work_item)
  end

  it 'has one `synced_epic`' do
    is_expected.to have_one(:synced_epic)
      .class_name('Epic')
      .with_foreign_key('issue_id')
      .inverse_of(:work_item)
  end

  it { is_expected.to have_one(:current_status).class_name('WorkItems::Statuses::CurrentStatus') }

  describe 'custom validations' do
    subject(:valid?) { work_item.valid? }

    describe 'due_date_after_start_date' do
      context 'when type is epic' do
        context 'when both values are not present' do
          let(:work_item) { build(:work_item, :epic, namespace: reusable_group) }

          it { is_expected.to be_truthy }
        end

        context 'when due date is before start date' do
          let(:work_item) do
            build(:work_item, :epic, namespace: reusable_group, due_date: 1.week.ago, start_date: 1.week.from_now)
          end

          it { is_expected.to be_truthy }
        end
      end
    end
  end

  describe '#sync_callback_class' do
    context 'with non existent callback class' do
      it 'returns nil' do
        expect(described_class.sync_callback_class('fake_association')).to be_nil
      end
    end

    context 'with existent callback class' do
      it 'returns nil' do
        expect(described_class.sync_callback_class('pending_escalations')).to eq(
          ::WorkItems::DataSync::NonWidgets::PendingEscalations
        )
      end
    end
  end

  describe '#supported_quick_action_commands' do
    let(:work_item) { build(:work_item, :issue) }

    subject { work_item.supported_quick_action_commands }

    before do
      stub_licensed_features(issuable_health_status: true, issue_weights: true)
    end

    context 'when work item supports the health status widget' do
      let(:work_item) { build(:work_item, :objective) }

      it 'returns health status related quick action commands' do
        is_expected.to include(:health_status, :clear_health_status)
      end
    end

    context 'when work item does not the health status widget' do
      let(:work_item) { build(:work_item, :task) }

      it 'omits assignee related quick action commands' do
        is_expected.not_to include(:health_status, :clear_health_status)
      end
    end

    context 'when work item supports the weight widget' do
      let(:work_item) { build(:work_item, :task) }

      it 'returns labels related quick action commands' do
        is_expected.to include(:weight, :clear_weight)
      end
    end

    context 'when work item does not support the weight widget' do
      let(:work_item) { build(:work_item, :objective) }

      it 'omits labels related quick action commands' do
        is_expected.not_to include(:weight, :clear_weight)
      end
    end

    it 'includes ee specific quick actions' do
      is_expected.to include(:q)
    end
  end

  describe '#widgets' do
    subject(:widgets) { build(:work_item).widgets }

    it 'instantiates widgets with their widget definition' do
      expect(widgets.map(&:widget_definition)).to all(be_instance_of(WorkItems::WidgetDefinition))
    end

    context 'for weight widget' do
      context 'when issuable weights is licensed' do
        before do
          stub_licensed_features(issue_weights: true)
        end

        it 'returns an instance of the weight widget' do
          is_expected.to include(instance_of(WorkItems::Widgets::Weight))
        end
      end

      context 'when issuable weights is unlicensed' do
        before do
          stub_licensed_features(issue_weights: false)
        end

        it 'omits an instance of the weight widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Weight))
        end
      end
    end

    context 'for verification status widget', feature_category: :requirements_management do
      subject { build(:work_item, :requirement).widgets }

      context 'when requirements is licensed' do
        before do
          stub_licensed_features(requirements: true)
        end

        it 'returns an instance of the status widget' do
          is_expected.to include(instance_of(WorkItems::Widgets::VerificationStatus))
        end
      end

      context 'when verification status is unlicensed' do
        before do
          stub_licensed_features(requirements: false)
        end

        it 'omits an instance of the verification status widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::VerificationStatus))
        end
      end
    end

    context 'for iteration widget' do
      context 'when iterations is licensed' do
        let(:group) { create(:group) }
        let(:project) { create(:project, group: group) }

        subject { build(:work_item, *work_item_type, project: project).widgets }

        before do
          stub_licensed_features(iterations: true)
        end

        context 'when work item supports iteration' do
          where(:work_item_type) { [:task, :issue] }

          with_them do
            it 'returns an instance of the iteration widget' do
              is_expected.to include(instance_of(WorkItems::Widgets::Iteration))
            end
          end
        end

        context 'when work item does not support iteration' do
          let(:work_item_type) { :requirement }

          it 'omits an instance of the iteration widget' do
            is_expected.not_to include(instance_of(WorkItems::Widgets::Iteration))
          end
        end
      end

      context 'when iterations is unlicensed' do
        before do
          stub_licensed_features(iterations: false)
        end

        it 'omits an instance of the iteration widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Iteration))
        end
      end
    end

    context 'for progress widget' do
      context 'when okrs is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(okrs: true)
        end

        context 'when work item supports progress' do
          let(:work_item_type) { [:objective] }

          it 'returns an instance of the progress widget' do
            is_expected.to include(instance_of(WorkItems::Widgets::Progress))
          end
        end

        context 'when work item does not support progress' do
          let(:work_item_type) { :requirement }

          it 'omits an instance of the progress widget' do
            is_expected.not_to include(instance_of(WorkItems::Widgets::Progress))
          end
        end
      end

      context 'when okrs is unlicensed' do
        before do
          stub_licensed_features(okrs: false)
        end

        it 'omits an instance of the progress widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Progress))
        end
      end
    end

    context 'for color widget' do
      context 'when epic color is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(epic_colors: true)
        end

        context 'when work item supports color' do
          let(:work_item_type) { [:epic] }

          it 'returns an instance of the color widget' do
            is_expected.to include(instance_of(WorkItems::Widgets::Color))
          end
        end

        context 'when work item does not support color' do
          let(:work_item_type) { :requirement }

          it 'omits an instance of the color widget' do
            is_expected.not_to include(instance_of(WorkItems::Widgets::Color))
          end
        end
      end

      context 'when epic_colors is unlicensed' do
        before do
          stub_licensed_features(epic_colors: false)
        end

        it 'omits an instance of the color widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Color))
        end
      end
    end

    context 'for health status widget' do
      context 'when issuable_health_status is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(issuable_health_status: true)
        end

        context 'when work item supports health_status' do
          where(:work_item_type) { [:issue, :objective, :key_result] }

          with_them do
            it 'returns an instance of the health status widget' do
              is_expected.to include(instance_of(WorkItems::Widgets::HealthStatus))
            end
          end
        end

        context 'when work item does not support health status' do
          where(:work_item_type) { [:test_case, :requirement] }

          with_them do
            it 'omits an instance of the health status widget' do
              is_expected.not_to include(instance_of(WorkItems::Widgets::HealthStatus))
            end
          end
        end
      end

      context 'when issuable_health_status is unlicensed' do
        before do
          stub_licensed_features(issuable_health_status: false)
        end

        it 'omits an instance of the health status widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::HealthStatus))
        end
      end
    end

    context 'for legacy requirement widget', feature_category: :requirements_management do
      let(:work_item_type) { [:requirement] }

      context 'when requirements feature is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(requirements: true)
        end

        context 'when work item supports legacy requirement' do
          it 'returns an instance of the legacy requirement widget' do
            is_expected.to include(instance_of(WorkItems::Widgets::RequirementLegacy))
          end
        end

        context 'when work item does not support legacy requirement' do
          where(:work_item_type) { [:test_case, :issue, :objective, :key_result] }

          with_them do
            it 'omits an instance of the legacy requirement widget' do
              is_expected.not_to include(instance_of(WorkItems::Widgets::RequirementLegacy))
            end
          end
        end
      end

      context 'when requirements feature is unlicensed' do
        before do
          stub_licensed_features(requirements: false)
        end

        it 'omits an instance of the legacy requirement widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::RequirementLegacy))
        end
      end
    end
  end

  describe '#average_progress_of_children' do
    let_it_be_with_reload(:parent_work_item) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child_work_item1) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child_work_item2) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child_work_item3) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child1_progress) { create(:progress, work_item: child_work_item1, progress: 20) }
    let_it_be_with_reload(:child2_progress) { create(:progress, work_item: child_work_item2, progress: 30) }
    let_it_be_with_reload(:child3_progress) { create(:progress, work_item: child_work_item3, progress: 30) }

    context 'when workitem has zero children' do
      it 'returns 0 as average' do
        expect(parent_work_item.average_progress_of_children).to eq(0)
      end
    end

    context 'when work item has children' do
      before_all do
        create(:parent_link, work_item: child_work_item1, work_item_parent: parent_work_item)
        create(:parent_link, work_item: child_work_item2, work_item_parent: parent_work_item)
      end

      it 'returns the average of children progress' do
        expect(parent_work_item.average_progress_of_children).to eq(25)
      end

      it 'rounds the average to lower number' do
        create(:parent_link, work_item: child_work_item3, work_item_parent: parent_work_item)

        expect(parent_work_item.average_progress_of_children).to eq(26)
      end
    end
  end

  it_behaves_like 'a collection filtered by test reports state', feature_category: :requirements_management do
    let_it_be(:requirement1) { create(:work_item, :requirement) }
    let_it_be(:requirement2) { create(:work_item, :requirement) }
    let_it_be(:requirement3) { create(:work_item, :requirement) }
    let_it_be(:requirement4) { create(:work_item, :requirement) }

    before do
      create(:test_report, requirement_issue: requirement1, state: :passed)
      create(:test_report, requirement_issue: requirement1, state: :failed)
      create(:test_report, requirement_issue: requirement2, state: :failed)
      create(:test_report, requirement_issue: requirement2, state: :passed)
      create(:test_report, requirement_issue: requirement3, state: :passed)
    end
  end

  describe '#linked_work_items', feature_category: :portfolio_management do
    let_it_be(:user) { create(:user) }

    let_it_be(:authorized_project) { create(:project, :private) }
    let_it_be(:work_item) { create(:work_item, project: authorized_project) }
    let_it_be(:authorized_item_a) { create(:work_item, project: authorized_project) }
    let_it_be(:authorized_item_b) { create(:work_item, project: authorized_project) }

    let_it_be(:unauthorized_project) { create(:project, :private) }
    let_it_be(:unauthorized_item_a) { create(:work_item, project: unauthorized_project) }
    let_it_be(:unauthorized_item_b) { create(:work_item, project: unauthorized_project) }

    let_it_be(:link_a) { create(:work_item_link, source: work_item, target: authorized_item_a, link_type: 'blocks') }
    let_it_be(:link_b) { create(:work_item_link, source: authorized_item_b, target: work_item, link_type: 'blocks') }
    let_it_be(:unauthorized_link_a) do
      create(:work_item_link, source: work_item, target: unauthorized_item_a, link_type: 'blocks')
    end

    let_it_be(:unauthorized_link_b) do
      create(:work_item_link, source: unauthorized_item_b, target: work_item, link_type: 'blocks')
    end

    before_all do
      authorized_project.add_guest(user)
    end

    it 'returns only authorized linked items for given user' do
      expect(work_item.linked_work_items(user))
        .to contain_exactly(authorized_item_a, authorized_item_b)
    end

    context 'when filtering by link type' do
      it 'returns authorized items with link type `blocks`' do
        expect(work_item.linked_work_items(user, link_type: 'blocks'))
          .to contain_exactly(authorized_item_a)
      end

      it 'returns authorized items with link type `is_blocked_by`' do
        expect(work_item.linked_work_items(user, link_type: 'is_blocked_by'))
          .to contain_exactly(authorized_item_b)
      end
    end
  end

  describe '.with_reminder_frequency' do
    let(:frequency) { 'weekly' }
    let!(:weekly_reminder_work_item) { create(:work_item, project: reusable_project) }
    let!(:weekly_progress) { create(:progress, work_item: weekly_reminder_work_item, reminder_frequency: 'weekly') }
    let!(:monthly_reminder_work_item) { create(:work_item, project: reusable_project) }
    let!(:montly_progress) { create(:progress, work_item: monthly_reminder_work_item, reminder_frequency: 'monthly') }
    let!(:no_reminder_work_item) { create(:work_item, project: reusable_project) }

    subject { described_class.with_reminder_frequency(frequency) }

    it { is_expected.to contain_exactly(weekly_reminder_work_item) }
  end

  describe '.without_parent' do
    let!(:parent_work_item) { create(:work_item, :objective, project: reusable_project) }
    let!(:work_item_with_parent) { create(:work_item, :key_result, project: reusable_project) }
    let!(:parent_link) { create(:parent_link, work_item_parent: parent_work_item, work_item: work_item_with_parent) }
    let!(:work_item_without_parent) { create(:work_item, :key_result, project: reusable_project) }

    subject { described_class.without_parent }

    it { is_expected.to contain_exactly(parent_work_item, work_item_without_parent) }
  end

  describe '.with_assignees' do
    let_it_be(:user) { create(:user) }
    let_it_be(:with_assignee) { create(:work_item, project: reusable_project) }
    let_it_be(:without_assignee) { create(:work_item, :key_result, project: reusable_project) }

    before_all do
      with_assignee.assignees = [user]
    end

    subject { described_class.with_assignees }

    it { is_expected.to contain_exactly(with_assignee) }
  end

  describe '.with_descendents_of' do
    let!(:parent_work_item) { create(:work_item, :objective, project: reusable_project) }
    let!(:work_item_with_parent) { create(:work_item, :key_result, project: reusable_project) }
    let!(:parent_link) { create(:parent_link, work_item_parent: parent_work_item, work_item: work_item_with_parent) }
    let!(:work_item_without_child) { create(:work_item, :key_result, project: reusable_project) }

    subject { described_class.with_descendents_of([parent_work_item.id, work_item_without_child.id]) }

    it { is_expected.to contain_exactly(work_item_with_parent) }
  end

  describe '.with_previous_reminder_sent_before' do
    let!(:work_item_without_progress) { create(:work_item, :objective, project: reusable_project) }
    let!(:work_item_with_recent_reminder) { create(:work_item, :objective, project: reusable_project) }
    let!(:work_item_with_stale_reminder) { create(:work_item, :objective, project: reusable_project) }
    let!(:recent_reminder) do
      create(:progress, work_item: work_item_with_recent_reminder, last_reminder_sent_at: 1.day.ago)
    end

    let!(:stale_reminder) do
      create(:progress, work_item: work_item_with_stale_reminder, last_reminder_sent_at: 3.days.ago)
    end

    subject { described_class.with_previous_reminder_sent_before(2.days.ago) }

    it { is_expected.to contain_exactly(work_item_without_progress, work_item_with_stale_reminder) }
  end

  describe 'status scopes' do
    let_it_be(:project) { create(:project, group: reusable_group) }

    let_it_be(:wi_no_status) { create(:work_item, :incident, project: project) }
    let_it_be(:wi_default_open) { create(:work_item, project: project) }
    let_it_be(:wi_default_closed) { create(:work_item, :closed, project: project) }
    let_it_be(:wi_default_duplicated) do
      create(:work_item, :closed, project: project, duplicated_to_id: wi_default_closed.id)
    end

    let_it_be(:system_defined_todo_status) { build(:work_item_system_defined_status, :to_do) }
    let_it_be(:system_defined_done_status) { build(:work_item_system_defined_status, :done) }
    let_it_be(:system_defined_duplicate_status) { build(:work_item_system_defined_status, :duplicate) }
    let_it_be(:system_defined_wont_do_status) { build(:work_item_system_defined_status, :wont_do) }

    let_it_be(:wi_system_defined_todo) do
      create(:work_item, project: project, system_defined_status_id: system_defined_todo_status.id)
    end

    let_it_be(:wi_system_defined_done) do
      create(:work_item, :closed, project: project, system_defined_status_id: system_defined_done_status.id)
    end

    let_it_be(:wi_system_defined_duplicated) do
      create(:work_item, :closed, project: project, system_defined_status_id: system_defined_duplicate_status.id)
    end

    let_it_be(:wi_system_defined_wont_do) do
      create(:work_item, :closed, project: project, system_defined_status_id: system_defined_wont_do_status.id)
    end

    let_it_be(:lifecycle) do
      create(:work_item_custom_lifecycle, namespace: reusable_group).tap do |lifecycle|
        # Skip validations so that we can skip the license check.
        # We can't stub licensed features for let_it_be blocks.
        build(:work_item_type_custom_lifecycle,
          namespace: reusable_group,
          work_item_type: create(:work_item_type, :issue),
          lifecycle: lifecycle
        ).save!(validate: false)
      end
    end

    let_it_be(:custom_status) do
      create(:work_item_custom_status,
        namespace: reusable_group,
        lifecycles: [lifecycle],
        converted_from_system_defined_status_identifier: nil
      )
    end

    let_it_be(:wi_custom_todo) do
      create(:work_item, project: project, custom_status_id: lifecycle.default_open_status_id)
    end

    let_it_be(:wi_custom_done) do
      create(:work_item, project: project, custom_status_id: lifecycle.default_closed_status_id)
    end

    let_it_be(:wi_custom_duplicated) do
      create(:work_item, project: project, custom_status_id: lifecycle.default_duplicate_status_id)
    end

    let_it_be(:wi_custom) { create(:work_item, project: project, custom_status_id: custom_status.id) }

    describe '.with_status' do
      subject { described_class.with_status(status) }

      context 'with a system defined status' do
        let(:status) { system_defined_todo_status }

        it 'returns items with matching current_status or its equivalent fallback state' do
          is_expected.to contain_exactly(wi_system_defined_todo, wi_default_open)
        end
      end

      context 'with custom todo status' do
        let(:status) { lifecycle.default_open_status }

        it 'returns items with matching current_status or the system defined status it was converted from' do
          is_expected.to contain_exactly(wi_custom_todo, wi_system_defined_todo, wi_default_open)
        end
      end

      context 'with custom done status' do
        let(:status) { lifecycle.default_closed_status }

        it 'returns items with matching current_status or the system defined status it was converted from' do
          is_expected.to contain_exactly(wi_custom_done, wi_system_defined_done, wi_default_closed)
        end
      end

      context 'with custom duplicated status' do
        let(:status) { lifecycle.default_duplicate_status }

        it 'returns items with matching current_status or the system defined status it was converted from' do
          is_expected.to contain_exactly(wi_custom_duplicated, wi_system_defined_duplicated, wi_default_duplicated)
        end
      end

      context 'with a custom status' do
        let(:status) { custom_status }

        it 'returns items with matching current_status' do
          is_expected.to contain_exactly(wi_custom)
        end
      end
    end

    describe '.with_system_defined_status' do
      subject { described_class.with_system_defined_status(status) }

      context 'with todo status' do
        let(:status) { system_defined_todo_status }

        it 'returns items with matching current_status or open items' do
          is_expected.to contain_exactly(wi_system_defined_todo, wi_default_open)
        end
      end

      context 'with done status' do
        let(:status) { system_defined_done_status }

        it 'returns items with matching current_status or closed items' do
          is_expected.to contain_exactly(wi_system_defined_done, wi_default_closed)
        end
      end

      context 'with duplicate status' do
        let(:status) { system_defined_duplicate_status }

        it 'returns items with matching current_status or duplicated items' do
          is_expected.to contain_exactly(wi_system_defined_duplicated, wi_default_duplicated)
        end
      end

      context 'with wont_do status' do
        let(:status) { system_defined_wont_do_status }

        it 'returns items with matching current_status' do
          is_expected.to contain_exactly(wi_system_defined_wont_do)
        end
      end

      context 'with a custom status' do
        let(:status) { custom_status }

        it 'returns no items' do
          is_expected.to be_empty
        end
      end
    end

    describe '.without_current_status' do
      it 'returns items that do not have an associated current_status' do
        expect(described_class.without_current_status).to contain_exactly(
          wi_default_open, wi_default_closed, wi_default_duplicated, wi_no_status
        )
      end
    end

    describe '.not_in_statuses' do
      subject { described_class.not_in_statuses(statuses) }

      context 'with empty statuses' do
        let(:statuses) { [] }

        it 'returns all work items' do
          is_expected.to contain_exactly(
            wi_default_open, wi_default_closed, wi_default_duplicated,
            wi_system_defined_todo, wi_system_defined_done, wi_system_defined_duplicated, wi_system_defined_wont_do,
            wi_custom_todo, wi_custom_done, wi_custom_duplicated, wi_custom, wi_no_status
          )
        end
      end

      context 'with system-defined statuses' do
        let(:statuses) do
          [
            system_defined_todo_status, system_defined_done_status,
            system_defined_duplicate_status, system_defined_wont_do_status
          ]
        end

        it 'excludes items with matching current_status or its equivalent fallback status' do
          is_expected.to contain_exactly(
            wi_custom_todo, wi_custom_done, wi_custom_duplicated, wi_custom, wi_no_status
          )
        end
      end

      context 'with custom statuses' do
        context 'with statuses that has system-defined mapping' do
          let(:statuses) do
            [lifecycle.default_open_status, lifecycle.default_closed_status, lifecycle.default_duplicate_status]
          end

          it 'excludes items with custom status and mapped system-defined items' do
            is_expected.to contain_exactly(
              wi_system_defined_wont_do, wi_custom, wi_no_status
            )
          end
        end

        context 'with status without system-defined mapping' do
          let(:statuses) { [custom_status] }

          it 'excludes only items with the custom status' do
            is_expected.not_to include(wi_custom)
          end
        end
      end
    end
  end

  describe 'versioned descriptions' do
    it_behaves_like 'versioned description'

    context 'when it is a work item of type epic' do
      let(:type) { create(:work_item_type, :epic) }
      let(:work_item) do
        create(:work_item, description: 'Original description', work_item_type: type, project: reusable_project)
      end

      it 'creates a versioned description on epic work item' do
        expect { work_item.update!(description: 'Another description') }
          .to change { work_item.own_description_versions.count }
      end

      context 'when set to skip description version' do
        it 'does not create a versioned description on epic work item' do
          expect { work_item.update!(description: 'Another description', skip_description_version: true) }
            .not_to change { work_item.own_description_versions.count }
        end
      end
    end
  end

  describe '#ensure_metrics!' do
    context 'with project-level work item' do
      subject(:create_work_item) { create(:work_item, project: reusable_project, work_item_type: type) }

      context 'when it is not a work item of type epic' do
        let(:type) { WorkItems::Type.default_by_type(:issue) }

        it 'creates metrics after saving' do
          expect(create_work_item).to be_persisted

          expect(Issue::Metrics.count).to eq(1)
        end
      end

      context 'when it is a project work item of type epic' do
        let(:type) { WorkItems::Type.default_by_type(:epic) }

        it 'creates metrics after saving' do
          expect(create_work_item).to be_persisted

          expect(Issue::Metrics.count).to eq(1)
        end
      end
    end

    context 'with grup-level work item' do
      subject(:create_work_item) do
        create(:work_item, namespace: reusable_group, work_item_type: WorkItems::Type.default_by_type(:epic))
      end

      it 'does not create metrics after saving work item with type epic' do
        expect(create_work_item).to be_persisted

        expect(Issue::Metrics.count).to eq(0)
      end
    end
  end

  describe '#allowed_work_item_type_change' do
    context 'when epic work item does not have a synced legacy epic' do
      let(:work_item) { create(:work_item, :epic) }

      it 'is does change work item type from epic to issue' do
        work_item.assign_attributes(work_item_type: WorkItems::Type.default_by_type(:issue))

        expect(work_item).to be_valid
        expect(work_item.errors[:work_item_type_id]).to be_empty
      end
    end

    context 'when epic work item has a synced legacy epic' do
      let!(:epic) { create(:epic, :with_synced_work_item) }
      let(:work_item) { epic.work_item }

      it 'is does not change work item type from epic to issue' do
        work_item.assign_attributes(work_item_type: WorkItems::Type.default_by_type(:issue))

        expect(work_item).not_to be_valid
        expect(work_item.errors[:work_item_type_id])
          .to include(_('cannot be changed to issue when the work item is a legacy epic synced work item'))
      end
    end
  end

  describe '#use_elasticsearch?' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:work_item) { create(:work_item, namespace: namespace) }

    context 'when namespace does not use elasticsearch' do
      it 'returns false' do
        stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_limit_indexing: true)

        expect(work_item.use_elasticsearch?).to be_falsey
      end
    end

    context 'when work_item index is available and namesapce uses elasticsearch' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_limit_indexing: false)
      end

      it 'returns true' do
        expect(work_item.use_elasticsearch?).to be_truthy
      end
    end
  end

  describe '.work_item_children_by_relative_position' do
    subject { parent_item.reload.work_item_children_by_relative_position }

    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:parent_item) { create(:work_item, :epic, namespace: namespace) }
    let_it_be(:oldest_item) { create(:work_item, :epic, namespace: namespace) }
    let_it_be(:middle_item) { create(:work_item, :issue, project: reusable_project) }
    let_it_be(:newest_item) { create(:work_item, :issue, project: reusable_project) }
    let_it_be(:closed_item) { create(:work_item, :issue, :closed, project: reusable_project) }

    let_it_be_with_reload(:link_to_oldest_item) do
      create(:parent_link, work_item_parent: parent_item, work_item: oldest_item)
    end

    let_it_be_with_reload(:link_to_middle_item) do
      create(:parent_link, work_item_parent: parent_item, work_item: middle_item)
    end

    let_it_be_with_reload(:link_to_newest_item) do
      create(:parent_link, work_item_parent: parent_item, work_item: newest_item)
    end

    let_it_be_with_reload(:link_to_closed_tiem) do
      create(:parent_link, work_item_parent: parent_item, work_item: closed_item, relative_position: 1)
    end

    context 'when subepics are not available' do
      before do
        stub_licensed_features(subepics: false)
      end

      context 'when ordered by relative position does not include subepics' do
        using RSpec::Parameterized::TableSyntax

        where(:oldest_item_position, :middle_item_position, :newest_item_position, :expected_order) do
          nil | nil | nil | lazy { [middle_item, newest_item, closed_item] }
          nil | nil | 2   | lazy { [newest_item, middle_item, closed_item] }
          nil | 2   | 3   | lazy { [middle_item, newest_item, closed_item] }
          3   | 4   | 2   | lazy { [newest_item, middle_item, closed_item] }
          2   | 3   | 4   | lazy { [middle_item, newest_item, closed_item] }
          2   | 4   | 3   | lazy { [newest_item, middle_item, closed_item] }
          3   | 2   | 4   | lazy { [middle_item, newest_item, closed_item] }
          4   | 2   | 3   | lazy { [middle_item, newest_item, closed_item] }
          4   | 3   | 2   | lazy { [newest_item, middle_item, closed_item] }
          2   | 3   | 2   | lazy { [newest_item, middle_item, closed_item] }
        end

        with_them do
          before do
            link_to_oldest_item.update!(relative_position: oldest_item_position)
            link_to_middle_item.update!(relative_position: middle_item_position)
            link_to_newest_item.update!(relative_position: newest_item_position)
          end

          it { is_expected.to eq(expected_order) }
        end
      end
    end

    context 'when subepics are available' do
      before do
        stub_licensed_features(subepics: true)
      end

      # Skipped order related specs since they are tested in work_item_spec file in CE
      it 'return child epics as well in the children' do
        expect(parent_item.reload.work_item_children_by_relative_position).to eq([oldest_item, middle_item,
          newest_item, closed_item])
      end
    end
  end

  describe '#preload_indexing_data' do
    let_it_be(:work_item) { create(:work_item) }

    it 'preloads for indexing and avoid N+1 queries' do
      work_item = described_class.preload_indexing_data.first
      recorder = ActiveRecord::QueryRecorder.new do
        work_item.namespace
        work_item.labels
        work_item.project.project_feature
        work_item.milestone
      end
      expect(recorder.count).to be_zero
    end
  end

  describe '#elastic_reference' do
    let(:work_item) { create(:work_item) }

    it 'returns the string representation for the elasticsearch' do
      expect(work_item.elastic_reference).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end
  end

  describe '#es_parent' do
    let(:namespace) { create(:namespace) }
    let(:work_item) { create(:work_item, namespace: namespace) }

    it 'returns to correct routing id' do
      expect(work_item.es_parent).to eq("group_#{namespace.root_ancestor.id}")
    end
  end

  context 'when deleting a work item' do
    context 'and associated legacy epic has award emojis' do
      let_it_be_with_reload(:work_item) { create(:work_item, :epic_with_legacy_epic) }
      let_it_be_with_reload(:epic) { work_item.sync_object }
      let_it_be(:emoji_1) { create(:award_emoji, awardable: work_item) }
      let_it_be(:emoji_2) { create(:award_emoji, awardable: epic) }
      let_it_be(:emoji_3) { create(:award_emoji, awardable: epic) }
      let_it_be(:emoji_4) { create(:award_emoji) } # Not to be deleted

      it 'also deletes award emoji from legacy epic' do
        expect { work_item.destroy! }.to change { ::AwardEmoji.count }.by(-3)
        expect(emoji_4.reload).to be_persisted
      end
    end
  end

  context 'with subscriptions' do
    context 'when type is Epic' do
      let_it_be(:epic) { create(:epic, group: reusable_group) }
      let_it_be(:work_item) { epic.work_item }
      let_it_be(:epic_subscription) { create(:subscription, user: user, subscribable: epic, subscribed: true) }

      context 'when subscriptions are read from the epic and the epic work item' do
        it 'returns subscriptions from both' do
          expect(epic.reload.subscriptions).to contain_exactly(epic_subscription)
          expect(work_item.reload.subscriptions).to contain_exactly(epic_subscription)
        end
      end
    end
  end

  describe '.linked_items_for' do
    let_it_be(:items) { create_list(:work_item, 3, project: reusable_project) }
    let_it_be(:linked_items) { create_list(:work_item, 3, project: reusable_project) }

    subject(:linked_by_type) { described_class.linked_items_for(items.pluck(:id), link_type: type_filter) }

    before do
      create(:work_item_link, source: items[0], target: linked_items[0], link_type: 'relates_to')
      create(:work_item_link, source: items[1], target: linked_items[1], link_type: 'blocks')
      create(:work_item_link, source: linked_items[2], target: items[2], link_type: 'blocks')
    end

    where(type_filter: %w[relates_to blocks is_blocked_by])

    with_them do
      it 'returns the linked items with the specified link type' do
        expect(linked_by_type.first.issue_link_type).to eq(type_filter)
        expect(linked_by_type.first.issue_link_type).to eq(type_filter)
      end
    end
  end

  describe '#status_with_fallback' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let_it_be_with_reload(:work_item) { create(:work_item, :task, project: project) }

    before do
      stub_licensed_features(work_item_status: true)
    end

    subject(:status_with_fallback) { work_item.status_with_fallback }

    context 'with system-defined lifecycle' do
      let(:lifecycle) do
        WorkItems::Statuses::SystemDefined::Lifecycle.of_work_item_base_type(work_item.work_item_type.base_type)
      end

      context 'when current_status exists' do
        before do
          create(:work_item_current_status,
            work_item: work_item,
            system_defined_status_id: lifecycle.default_open_status_id
          )
        end

        it 'returns the current status' do
          expect(status_with_fallback.class).to eq(WorkItems::Statuses::SystemDefined::Status)
          expect(status_with_fallback.id).to eq(lifecycle.default_open_status_id)
        end
      end

      context 'when current_status does not exist' do
        context 'when state is open' do
          before do
            work_item.state = :opened
          end

          it 'returns the default open status' do
            expect(status_with_fallback.class).to eq(WorkItems::Statuses::SystemDefined::Status)
            expect(status_with_fallback.id).to eq(lifecycle.default_open_status_id)
          end
        end

        context 'when state is closed' do
          before do
            work_item.state = :closed
          end

          it 'returns the default closed status' do
            expect(status_with_fallback.class).to eq(WorkItems::Statuses::SystemDefined::Status)
            expect(status_with_fallback.id).to eq(lifecycle.default_closed_status_id)
          end

          context 'when work item is a duplicate' do
            before do
              work_item.duplicated_to = build_stubbed(:work_item)
            end

            it 'returns the default duplicated status' do
              expect(status_with_fallback.class).to eq(WorkItems::Statuses::SystemDefined::Status)
              expect(status_with_fallback.id).to eq(lifecycle.default_duplicate_status_id)
            end
          end
        end

        context 'when work item type does not have a lifecycle' do
          before do
            work_item.work_item_type = create(:work_item_type, :incident)
          end

          it 'returns nil' do
            expect(status_with_fallback).to be_nil
          end
        end
      end
    end

    context 'with custom lifecycle' do
      let!(:lifecycle) do
        create(:work_item_custom_lifecycle, namespace: group, work_item_types: [work_item.work_item_type])
      end

      context 'when current_status exists with custom_status_id' do
        before do
          create(:work_item_current_status,
            work_item: work_item,
            custom_status_id: lifecycle.default_open_status_id
          )
        end

        it 'returns the current custom status' do
          expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
          expect(status_with_fallback.id).to eq(lifecycle.default_open_status_id)
        end
      end

      context 'when current_status exists with system_defined_status_id' do
        before do
          # Skip validations since we are simulating an old record
          # when the namespace still used the system defined lifecycle
          build(:work_item_current_status,
            work_item: work_item,
            system_defined_status_id: lifecycle.default_open_status.converted_from_system_defined_status_identifier
          ).save!(validate: false)
        end

        it 'returns the converted custom status' do
          expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
          expect(status_with_fallback.id).to eq(lifecycle.default_open_status_id)
        end
      end

      context 'when current_status does not exist' do
        context 'when state is open' do
          before do
            work_item.state = :opened
          end

          it 'returns the converted default open status' do
            expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
            expect(status_with_fallback.id).to eq(lifecycle.default_open_status_id)
          end
        end

        context 'when state is closed' do
          before do
            work_item.state = :closed
          end

          it 'returns the converted default closed status' do
            expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
            expect(status_with_fallback.id).to eq(lifecycle.default_closed_status_id)
          end

          context 'when work item is a duplicate' do
            before do
              work_item.duplicated_to = build_stubbed(:work_item)
            end

            it 'returns the converted default duplicated status' do
              expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
              expect(status_with_fallback.id).to eq(lifecycle.default_duplicate_status_id)
            end
          end
        end
      end
    end
  end

  describe '#current_status_with_fallback' do
    let_it_be(:lifecycle) { build(:work_item_system_defined_lifecycle) }
    let_it_be_with_reload(:work_item) { create(:work_item, :task) }

    before do
      stub_licensed_features(work_item_status: true)
    end

    subject(:current_status_with_fallback) { work_item.current_status_with_fallback }

    context 'when current_status exists' do
      let_it_be(:current_status) do
        create(:work_item_current_status, work_item: work_item, system_defined_status: lifecycle.default_open_status)
      end

      it 'returns the current status' do
        expect(current_status_with_fallback).to eq(current_status)
      end
    end

    context 'when current_status does not exist' do
      context 'when state is open' do
        let(:expected_current_status) do
          work_item.build_current_status(system_defined_status: lifecycle.default_open_status)
        end

        before do
          work_item.state = :opened
        end

        it 'returns the initialized current status with default open status as status' do
          expect(current_status_with_fallback.persisted?).to be_falsey
          expect(current_status_with_fallback.class).to eq(WorkItems::Statuses::CurrentStatus)
          expect(current_status_with_fallback.system_defined_status).to eq(lifecycle.default_open_status)
        end
      end

      context 'when state is closed' do
        before do
          work_item.state = :closed
        end

        it 'returns the initialized current status with default closed status as status' do
          expect(current_status_with_fallback.persisted?).to be_falsey
          expect(current_status_with_fallback.class).to eq(WorkItems::Statuses::CurrentStatus)
          expect(current_status_with_fallback.system_defined_status).to eq(lifecycle.default_closed_status)
        end

        context 'when work item is a duplicate' do
          before do
            work_item.duplicated_to = build_stubbed(:work_item)
          end

          it 'returns the initialized current status with default duplicate status as status' do
            expect(current_status_with_fallback.persisted?).to be_falsey
            expect(current_status_with_fallback.class).to eq(WorkItems::Statuses::CurrentStatus)
            expect(current_status_with_fallback.system_defined_status).to eq(lifecycle.default_duplicate_status)
          end
        end

        context 'when work item type does not have a lifecycle' do
          before do
            work_item.work_item_type = create(:work_item_type, :incident)
          end

          it 'returns nil' do
            expect(current_status_with_fallback).to be_nil
          end
        end
      end
    end
  end
end
