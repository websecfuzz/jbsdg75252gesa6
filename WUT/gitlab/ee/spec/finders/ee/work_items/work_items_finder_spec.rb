# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::WorkItemsFinder, feature_category: :team_planning do
  context 'when filtering work items' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    before do
      stub_licensed_features(epics: true)
    end

    subject do
      described_class.new(user, params).execute
    end

    context 'with group parameter' do
      include_context 'Issues or WorkItems Finder context', :work_item

      include_context '{Issues|WorkItems}Finder#execute context', :work_item

      it_behaves_like 'work items finder group parameter', expect_group_items: true

      context 'when epics are disabled' do
        before do
          stub_licensed_features(epics: false)
        end

        let(:scope) { 'all' }
        let(:params) { { group_id: group } }
        let_it_be(:group_work_item) { create(:work_item, :group_level, namespace: group, author: user) }

        it 'returns group level work items' do
          expect(items).not_to include(group_work_item)
        end
      end
    end

    context 'with verification status widget' do
      let_it_be(:work_item1) { create(:work_item, project: project) }
      let_it_be(:work_item2) { create(:work_item, :satisfied_status, project: project) }

      let(:params) { { verification_status_widget: { verification_status: 'passed' } } }

      before do
        project.add_reporter(user)
      end

      it 'returns correct results' do
        is_expected.to match_array([work_item2])
      end
    end

    context 'with legacy requirement widget' do
      let_it_be(:work_item1) { create(:work_item, project: project) }
      let_it_be(:work_item2) { create(:work_item, :satisfied_status, project: project) }

      let(:params) { { requirement_legacy_widget: { legacy_iids: work_item2.requirement.iid } } }

      before do
        project.add_reporter(user)
      end

      it 'returns correct results' do
        is_expected.to match_array([work_item2])
      end
    end

    context 'when epic labels are split across epic and epic work item' do
      let_it_be(:label1) { create(:group_label, group: group) }
      let_it_be(:label2) { create(:group_label, group: group) }
      let_it_be(:label3) { create(:group_label, group: group) }
      let_it_be(:label4) { create(:group_label, group: group) }
      let_it_be(:label5) { create(:group_label, group: group) }
      let_it_be(:work_item1) { create(:work_item, :epic, namespace: group, title: 'group work item1') }
      let_it_be(:labeled_epic1) { create(:labeled_epic, group: group, title: 'labeled epic', labels: [label1, label2]) }
      let_it_be(:labeled_epic2) { create(:labeled_epic, group: group, title: 'labeled epic2', labels: [label4]) }
      let_it_be(:unlabeled_epic3) { create(:epic, group: group, title: 'labeled epic3') }
      let_it_be(:epic_work_item1) { labeled_epic1.work_item }
      let_it_be(:epic_work_item2) { labeled_epic2.work_item }
      let_it_be(:epic_work_item3) { unlabeled_epic3.work_item }

      let(:filtering_params) { {} }
      let(:params) { filtering_params.merge(group_id: group) }

      before do
        group.add_reporter(user)
        stub_licensed_features(epics: true)

        epic_work_item1.labels << label3
        epic_work_item2.labels << label5
      end

      context 'when when labels are set to epic and epic work item' do
        context 'when searching by NONE' do
          let(:filtering_params) { { label_name: ['None'] } }

          it 'returns correct epic work items' do
            # these epic work items have no labels neither on epic or epic work item side, e.g.
            is_expected.to contain_exactly(work_item1, epic_work_item3)
          end
        end

        context 'with `and` search' do
          context 'when searching by label assigned only to epic' do
            let(:filtering_params) { { label_name: [label2.title] } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(epic_work_item1)
            end
          end

          context 'when searching by a combination of labels assigned to epic and epic work item' do
            let(:filtering_params) { { label_name: [label3.title, label1.title] } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(epic_work_item1)
            end
          end
        end

        context 'with `or` search' do
          context 'when searching by label assigned only to epic' do
            let(:filtering_params) { { or: { label_name: [label1.title, label4.title] } } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(epic_work_item1, epic_work_item2)
            end
          end

          context 'when searching by a combination of labels assigned to epic and epic work item' do
            let(:filtering_params) { { or: { label_name: [label1.title, label5.title] } } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(epic_work_item1, epic_work_item2)
            end
          end
        end

        context 'with `not` search' do
          context 'when searching by label assigned only to epic' do
            let(:filtering_params) { { not: { label_name: [label1.title, label4.title] } } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(*(group.work_items.to_a - [epic_work_item1, epic_work_item2]))
            end
          end

          context 'when searching by a combination of labels assigned to epic and epic work item' do
            let(:filtering_params) { { not: { label_name: [label1.title, label5.title] } } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(*(group.work_items.to_a - [epic_work_item1, epic_work_item2]))
            end
          end
        end
      end
    end

    context 'when emojis are present on its associated legacy epic' do
      before do
        stub_licensed_features(epics: true)
      end

      let_it_be(:object1) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:object2) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:object3) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:object4) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

      it_behaves_like 'filter by unified emoji association'
    end

    describe 'filtering by issue_types' do
      let_it_be(:current_user) { create(:user) }
      let_it_be(:group) { create(:group, developers: [current_user]) }
      let_it_be(:subgroup) { create(:group, developers: [current_user], parent: group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:subgroup_project) { create(:project, group: subgroup) }

      let_it_be(:task) { create(:work_item, :task, author: current_user, project: project) }
      let_it_be(:project_issue) { create(:work_item, author: current_user, project: project) }
      let_it_be(:group_issue) { create(:work_item, author: current_user, namespace: group) }
      let_it_be(:project_epic) { create(:work_item, :epic, author: current_user, project: project) }
      let_it_be(:group_epic) { create(:work_item, :epic, author: current_user, namespace: group) }
      let_it_be(:subgroup_epic) { create(:work_item, :epic, author: current_user, namespace: subgroup) }
      let_it_be(:subproject_epic) { create(:work_item, :epic, author: current_user, project: project) }

      let(:params) { {} }

      subject(:items) { described_class.new(current_user, params.reverse_merge(scope: 'all', state: 'opened')).execute }

      context 'with group param' do
        context 'with include_descendants as false' do
          let(:params) { { group_id: group, include_descendants: false } }

          context 'when epics feature is available' do
            before do
              stub_licensed_features(epics: true)
            end

            it { is_expected.to contain_exactly(group_issue, group_epic) }
          end

          context 'when epics feature is not available' do
            before do
              stub_licensed_features(epics: false)
            end

            it { is_expected.to be_empty }

            context 'when issue_types param is epic' do
              let(:params) { { group_id: group, include_descendants: false, issue_types: 'epic' } }

              it { is_expected.to be_empty }
            end
          end
        end

        context 'with include_descendants as true' do
          let(:params) { { group_id: group, include_descendants: true } }

          context 'when epics feature is available' do
            before do
              stub_licensed_features(epics: true)
            end

            it 'returns allowed types' do
              is_expected.to contain_exactly(
                task,
                project_issue,
                project_epic,
                group_issue,
                group_epic,
                subgroup_epic,
                subproject_epic
              )
            end

            context 'when project_work_item_epics feature flag is disabled' do
              before do
                stub_feature_flags(project_work_item_epics: false)
              end

              it { is_expected.to contain_exactly(task, project_issue, group_issue, group_epic, subgroup_epic) }

              context 'and issue_types param is epic' do
                let(:params) { { group_id: group, include_descendants: true, issue_types: 'epic' } }

                it { is_expected.to contain_exactly(group_epic, subgroup_epic) }
              end

              context 'and issue_types param includes epic' do
                let(:params) { { group_id: group, include_descendants: true, issue_types: %w[epic task] } }

                it { is_expected.to contain_exactly(task, group_epic, subgroup_epic) }
              end
            end
          end

          context 'when epics feature is not available' do
            before do
              stub_licensed_features(epics: false)
            end

            it { is_expected.to contain_exactly(task, project_issue) }

            context 'and issue_types param is epic' do
              let(:params) { { group_id: group, include_descendants: true, issue_types: 'epic' } }

              it { is_expected.to be_empty }
            end
          end
        end
      end
    end
  end
end
