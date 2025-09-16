# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::UpdateService, feature_category: :portfolio_management do
  let_it_be_with_refind(:group) { create(:group, :internal) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:epic) { create(:epic, group: group) }

  describe '#execute' do
    before do
      stub_licensed_features(epics: true, subepics: true, epic_colors: true)
      group.add_maintainer(user)
    end

    def find_note(starting_with)
      epic.notes.find do |note|
        note && note.note.start_with?(starting_with)
      end
    end

    def find_notes(action)
      epic
        .notes
        .joins(:system_note_metadata)
        .where(system_note_metadata: { action: action })
    end

    def update_epic(opts)
      described_class.new(group: group, current_user: user, params: opts).execute(epic)
    end

    it_behaves_like 'issuable update service updating last_edited_at values' do
      let(:issuable) { epic }
      subject(:update_issuable) { update_epic(update_params) }
    end

    context 'multiple values update' do
      let(:opts) do
        {
          title: 'New title',
          description: 'New description',
          start_date_fixed: '2017-01-09',
          start_date_is_fixed: true,
          due_date_fixed: '2017-10-21',
          due_date_is_fixed: true,
          state_event: 'close',
          confidential: true
        }
      end

      it 'updates the epic correctly' do
        update_epic(opts)

        expect(epic).to be_valid
        expect(epic).to have_attributes(opts.except(:due_date_fixed, :start_date_fixed, :state_event))
        expect(epic).to have_attributes(
          start_date_fixed: Date.strptime(opts[:start_date_fixed]),
          due_date_fixed: Date.strptime(opts[:due_date_fixed]),
          confidential: true
        )
        expect(epic).to be_closed
      end
    end

    it 'publishes an EpicUpdated event' do
      expect { update_epic({ title: 'New title' }) }
        .to publish_event(Epics::EpicUpdatedEvent)
        .with({ id: epic.id, group_id: group.id })
    end

    context 'when title has changed' do
      it 'creates system note about title change' do
        expect { update_epic(title: 'New title') }.to change { Note.count }.from(0).to(1)

        note = Note.last

        expect(note.note).to start_with('<p>changed title')
        expect(note.noteable).to eq(epic)
      end

      it 'records epic title changed after saving' do
        expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_title_changed_action).with(author: user, namespace: group)

        update_epic(title: 'New title')
      end
    end

    context 'when description has changed' do
      it 'creates system note about description change' do
        expect { update_epic(description: 'New description') }.to change { Note.count }.from(0).to(1)

        note = Note.last

        expect(note.note).to start_with('changed the description')
        expect(note.noteable).to eq(epic)
      end

      it 'records epic description changed after saving' do
        expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_description_changed_action).with(author: user, namespace: group)

        update_epic(description: 'New description')
      end

      it 'triggers GraphQL description updated subscription' do
        expect(GraphqlTriggers).to receive(:issuable_description_updated).with(epic).and_call_original

        update_epic(description: 'updated description')
      end

      it 'creates description version for epic only' do
        update_epic(description: 'New description')

        expect(epic.reload.own_description_versions.count).to eq(2)
        expect(epic.sync_object.reload.own_description_versions.count).to eq(0)
      end
    end

    context 'when description is not changed' do
      it 'does not trigger GraphQL description updated subscription' do
        expect(GraphqlTriggers).not_to receive(:issuable_description_updated)

        update_epic(title: 'updated title')
      end
    end

    context 'after_save callback to store_mentions' do
      let(:user2) { create(:user) }
      let(:epic) { create(:epic, group: group, description: "simple description") }
      let(:labels) { create_pair(:group_label, group: group) }

      context 'when mentionable attributes change' do
        let(:opts) { { description: "Description with #{user.to_reference}" } }

        it 'saves mentions' do
          expect(epic).to receive(:store_mentions!).and_call_original

          expect { update_epic(opts) }.to change { EpicUserMention.count }.by(1)

          expect(epic.referenced_users).to match_array([user])
        end
      end

      context 'when mentionable attributes do not change' do
        let(:opts) { { label_ids: labels.map(&:id) } }

        it 'does not call store_mentions!' do
          expect(epic).not_to receive(:store_mentions!).and_call_original

          expect { update_epic(opts) }.not_to change { EpicUserMention.count }

          expect(epic.referenced_users).to be_empty
        end
      end

      context 'when save fails' do
        let(:opts) { { title: '', label_ids: labels.map(&:id) } }

        it 'does not call store_mentions!' do
          expect(epic).not_to receive(:store_mentions!).and_call_original

          expect { update_epic(opts) }.not_to change { EpicUserMention.count }

          expect(epic.referenced_users).to be_empty
          expect(epic.valid?).to be false
        end
      end
    end

    context 'todos' do
      before do
        group.update!(visibility: Gitlab::VisibilityLevel::PUBLIC)
      end

      context 'creating todos' do
        let(:mentioned1) { create(:user) }
        let(:mentioned2) { create(:user) }

        before do
          epic.update!(description: "FYI: #{mentioned1.to_reference}")
        end

        it 'creates todos for only newly mentioned users' do
          expect do
            update_epic(description: "FYI: #{mentioned1.to_reference} #{mentioned2.to_reference}")
          end.to change { Todo.count }.by(1)
        end
      end

      context 'adding a label' do
        let(:label) { create(:group_label, group: group) }
        let(:user2) { create(:user) }
        let!(:todo1) do
          create(:todo, :mentioned, :pending,
            target: epic,
            group: group,
            project: nil,
            author: user,
            user: user)
        end

        let!(:todo2) do
          create(:todo, :mentioned, :pending,
            target: epic,
            group: group,
            project: nil,
            author: user2,
            user: user2)
        end

        subject { update_epic(label_ids: [label.id]) }

        before do
          group.add_developer(user)
        end

        it 'marks todo as done for a user who added a label' do
          subject

          expect(todo1.reload.state).to eq('done')
        end

        it 'does not mark todos as done for other users' do
          subject

          expect(todo2.reload.state).to eq('pending')
        end

        it 'tracks the label change' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter)
            .to receive(:track_epic_labels_changed_action).with(author: user, namespace: group)

          subject
        end
      end

      context 'mentioning a group in epic description' do
        let_it_be(:mentioned1) { create(:user, developer_of: group) }
        let_it_be(:mentioned2) { create(:user) }

        before do
          epic.update!(description: "FYI: #{group.to_reference}")
        end

        context 'when the group is public' do
          before do
            group.update!(visibility: Gitlab::VisibilityLevel::PUBLIC)
          end

          it 'creates todos for only newly mentioned users' do
            expect do
              update_epic(description: "FYI: #{mentioned1.to_reference} #{mentioned2.to_reference}")
            end.to change { Todo.count }.by(1)
          end
        end

        context 'when the group is private' do
          before do
            group.update!(visibility: Gitlab::VisibilityLevel::PRIVATE)
          end

          it 'creates todos for only newly mentioned users that are group members' do
            expect do
              update_epic(description: "FYI: #{mentioned1.to_reference} #{mentioned2.to_reference}")
            end.to change { Todo.count }
          end
        end
      end

      context 'when the epic becomes confidential' do
        it 'schedules deletion of todos' do
          expect(TodosDestroyer::ConfidentialEpicWorker).to receive(:perform_in).with(Todo::WAIT_FOR_DELETE, epic.id)

          update_epic(confidential: true)
        end

        it 'tracks the epic becoming confidential' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter)
            .to receive(:track_epic_confidential_action).with(author: user, namespace: group)

          update_epic(confidential: true)
        end
      end

      context 'when the epic becomes visible' do
        before do
          epic.update_column(:confidential, true)
        end

        it 'does not schedule deletion of todos' do
          expect(TodosDestroyer::ConfidentialEpicWorker).not_to receive(:perform_in)

          update_epic(confidential: false)
        end

        it 'tracks the epic becoming visible' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter)
            .to receive(:track_epic_visible_action).with(author: user, namespace: group)

          update_epic(confidential: false)
        end
      end
    end

    context 'when Epic has tasks' do
      before do
        update_epic(description: "- [ ] Task 1\n- [ ] Task 2")
      end

      it { expect(epic.tasks?).to eq(true) }

      it_behaves_like 'updating a single task' do
        def update_issuable(opts)
          described_class.new(group: group, current_user: user, params: opts).execute(epic)
        end
      end

      context 'when tasks are marked as completed' do
        it 'creates system note about task status change' do
          update_epic(description: "- [x] Task 1\n- [X] Task 2")

          note1 = find_note('marked the checklist item **Task 1** as completed')
          note2 = find_note('marked the checklist item **Task 2** as completed')

          expect(note1).not_to be_nil
          expect(note2).not_to be_nil

          description_notes = find_notes('description')
          expect(description_notes.length).to eq(1)
        end

        it 'counts the change correctly' do
          expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_task_checked)
            .with(author: user, namespace: group).twice

          update_epic(description: "- [x] Task 1\n- [X] Task 2")
        end
      end

      context 'when tasks are marked as incomplete' do
        before do
          update_epic(description: "- [x] Task 1\n- [X] Task 2")
        end

        it 'creates system note about task status change' do
          update_epic(description: "- [ ] Task 1\n- [ ] Task 2")

          note1 = find_note('marked the checklist item **Task 1** as incomplete')
          note2 = find_note('marked the checklist item **Task 2** as incomplete')

          expect(note1).not_to be_nil
          expect(note2).not_to be_nil

          description_notes = find_notes('description')
          expect(description_notes.length).to eq(1)
        end

        it 'counts the change correctly' do
          expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_task_unchecked)
            .with(author: user, namespace: group).twice

          update_epic(description: "- [ ] Task 1\n- [ ] Task 2")
        end
      end
    end

    context 'filter out start_date and end_date' do
      it 'ignores start_date and end_date' do
        expect { update_epic(start_date: Date.today, end_date: Date.today) }.not_to change { Note.count }

        expect(epic).to be_valid
        expect(epic).to have_attributes(start_date: nil, due_date: nil)
      end
    end

    context 'refresh epic dates' do
      context 'date fields are updated' do
        it 'calls UpdateDatesService' do
          expect(Epics::UpdateDatesService).to receive(:new).with([epic]).and_call_original

          update_epic(start_date_is_fixed: true, start_date_fixed: Date.today)
          epic.reload
          expect(epic.start_date).to eq(epic.start_date_fixed)
        end
      end

      context 'epic start date fixed or inherited' do
        it 'tracks the user action to set as fixed' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_start_date_set_as_fixed_action)
            .with(author: user, namespace: group)

          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_fixed_start_date_updated_action)
            .with(author: user, namespace: group)

          update_epic(start_date_is_fixed: true, start_date_fixed: Date.today)
        end

        it 'tracks the user action to set as inherited' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_start_date_set_as_inherited_action)
            .with(author: user, namespace: group)

          update_epic(start_date_is_fixed: false)
        end
      end

      context 'epic due date fixed or inherited' do
        it 'tracks the user action to set as fixed' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_due_date_set_as_fixed_action)
            .with(author: user, namespace: group)

          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_fixed_due_date_updated_action)
            .with(author: user, namespace: group)

          update_epic(due_date_is_fixed: true, due_date_fixed: Date.today)
        end

        it 'tracks the user action to set as inherited' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_due_date_set_as_inherited_action)
            .with(author: user, namespace: group)

          update_epic(due_date_is_fixed: false)
        end
      end

      context 'date fields are not updated' do
        it 'does not call UpdateDatesService' do
          expect(Epics::UpdateDatesService).not_to receive(:new)

          update_epic(title: 'foo')
        end
      end
    end

    it_behaves_like 'existing issuable with scoped labels' do
      let(:issuable) { epic }
      let(:parent) { group }
    end

    context 'updating labels' do
      let(:label_a) { create(:group_label, title: 'a', group: group) }
      let(:label_b) { create(:group_label, title: 'b', group: group) }
      let(:label_c) { create(:group_label, title: 'c', group: group) }
      let(:label_locked) { create(:group_label, title: 'locked', group: group, lock_on_merge: true) }
      let(:issuable) { epic }

      it_behaves_like 'updating issuable labels'
      it_behaves_like 'keeps issuable labels sorted after update'
      it_behaves_like 'broadcasting issuable labels updates'

      def update_issuable(update_params)
        update_epic(update_params)
      end
    end

    context 'with quick actions in the description' do
      before do
        stub_licensed_features(epics: true, subepics: true)
        group.add_developer(user)
      end

      context 'for /label' do
        let(:label) { create(:group_label, group: group) }

        it 'adds labels to the epic' do
          update_epic(description: "/label ~#{label.name}")

          expect(epic.label_ids).to contain_exactly(label.id)
        end
      end

      context 'for /parent_epic' do
        it 'assigns parent epic' do
          parent_epic = create(:epic, group: epic.group)
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_parent_updated_action)
            .with(author: user, namespace: group)

          update_epic(description: "/parent_epic #{parent_epic.to_reference}")

          expect(epic.parent).to eq(parent_epic)
        end

        context 'when parent epic cannot be assigned' do
          it 'does not update parent epic' do
            other_group = create(:group, :private)
            parent_epic = create(:epic, group: other_group)
            expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).not_to receive(:track_epic_parent_updated_action)

            update_epic(description: "/parent_epic #{parent_epic.to_reference(group)}")

            expect(epic.parent).to eq(nil)
          end
        end
      end

      context 'for /child_epic' do
        it 'sets a child epic' do
          child_epic = create(:epic, group: group)

          update_epic(description: "/child_epic #{child_epic.to_reference}")

          expect(epic.reload.children).to include(child_epic)
        end

        context 'when child epic cannot be assigned' do
          it 'does not set child epic' do
            other_group = create(:group, :private)
            child_epic = create(:epic, group: other_group)

            update_epic(description: "/child_epic #{child_epic.to_reference(group)}")
            expect(epic.reload.children).to be_empty
          end
        end
      end

      it_behaves_like 'issuable record does not run quick actions when not editing description' do
        let(:label) { create(:group_label, group: group) }
        let(:assignee) { create(:user, maintainer_of: group) }
        let(:epic) { create(:epic, group: group, description: old_description) }
        let(:updated_issuable) { update_epic(params) }
      end
    end

    context 'when updating parent' do
      let(:new_parent) { create(:epic, group: group) }

      subject { update_epic(parent: new_parent) }

      context 'when user cannot update parent' do
        shared_examples 'updates epic without changing parent' do
          it 'does not change parent' do
            expect { subject }.not_to change { epic.parent }
          end
        end

        context 'when subepics are disabled' do
          before do
            stub_licensed_features(epics: true, subepics: false)
          end

          it_behaves_like 'updates epic without changing parent'
        end

        context 'when user lacks permissions' do
          let_it_be_with_reload(:user) { create(:user) }

          before do
            new_parent.update!(confidential: true)
            group.add_guest(user)
          end

          it_behaves_like 'updates epic without changing parent'

          context 'when using parent_id' do
            subject { update_epic(parent_id: new_parent.id) }

            it 'does not change parent' do
              expect { subject }.not_to change { epic.parent }
            end
          end
        end
      end

      context 'when user can update parent' do
        shared_examples 'calls correct EpicLinks service' do |service_class|
          it 'calls correct service' do
            params = service_class == '::WorkItems::LegacyEpics::EpicLinks::CreateService' ? [new_parent, user, { target_issuable: epic }] : [epic, user]

            service_class = service_class.constantize
            allow_next_instance_of(service_class) do |service|
              allow(service).to receive(:execute).and_return({ status: :success })
            end

            expect(service_class).to receive(:new).with(*params)
            subject
          end
        end

        it 'creates system notes' do
          expect { subject }.to change { epic.parent }.from(nil).to(new_parent)
                                                      .and change { Note.count }.by(2)

          child_ref = epic.work_item.to_reference(group)
          new_ref = new_parent.work_item.to_reference(group)

          epic.reload
          expect(epic.notes.first.note).to eq("added #{new_ref} as parent epic")
          expect(new_parent.notes.first.note).to eq("added #{child_ref} as child epic")
        end

        it_behaves_like 'calls correct EpicLinks service', '::WorkItems::LegacyEpics::EpicLinks::CreateService'

        context 'when parent is already present' do
          let(:existing_parent) { create(:epic, group: group) }

          before do
            epic.update!(parent: existing_parent)
          end

          it 'changes parent and creates system notes' do
            expect { subject }.to change { epic.parent }.from(existing_parent).to(new_parent)
                                                        .and change { Note.count }.by(2)

            child_ref = epic.work_item.to_reference(group)
            new_ref = new_parent.work_item.to_reference(group)

            epic.reload
            expect(epic.notes.first.note).to eq("added #{new_ref} as parent epic")
            expect(new_parent.notes.first.note).to eq("added #{child_ref} as child epic")
          end

          it_behaves_like 'calls correct EpicLinks service', '::WorkItems::LegacyEpics::EpicLinks::CreateService'

          context 'when removing parent' do
            subject { update_epic(parent: nil) }

            it 'removes parent and creates system notes' do
              expect { subject }.to change { epic.parent }.from(existing_parent).to(nil)
                                                          .and change { Note.count }.by(2)

              child_ref = epic.to_reference(group)
              existing_ref = existing_parent.to_reference(group)

              epic.reload
              expect(epic.notes.first.note).to eq("removed parent epic #{existing_ref}")
              expect(existing_parent.notes.first.note).to eq("removed child epic #{child_ref}")
            end

            it_behaves_like 'calls correct EpicLinks service', 'Epics::EpicLinks::DestroyService'

            context 'when user cannot access parent' do
              before do
                allow(Ability).to receive(:allowed?).and_call_original
                allow(Ability).to receive(:allowed?)
                                    .with(user, :read_epic_relation, existing_parent).and_return(false)
              end

              it 'does not change parent' do
                expect { subject }.not_to change { epic.parent }
              end
            end
          end
        end
      end
    end

    context 'work item sync' do
      let_it_be(:group) { create(:group) }
      let_it_be(:labels) { create_pair(:group_label, group: group) }

      context 'when epic has a synced work item' do
        let_it_be_with_reload(:epic) { create(:epic, :with_synced_work_item, group: group) }
        let(:work_item) { epic.work_item }

        context 'multiple values update' do
          let_it_be(:synced_parent_work_item) { create(:work_item, :epic, namespace: group) }
          let_it_be(:parent_epic) { create(:epic, group: group, issue_id: synced_parent_work_item.id) }
          let_it_be(:start_date) { Date.new(2024, 1, 1) }
          let_it_be(:due_date) { Date.new(2024, 1, 31) }

          context 'when changes are valid' do
            let(:opts) do
              {
                title: 'New title',
                description: 'New description',
                confidential: true,
                external_key: 'external_test_key',
                color: '#CC0000',
                parent: parent_epic,
                start_date_is_fixed: true,
                start_date_fixed: start_date,
                due_date_is_fixed: true,
                due_date_fixed: due_date
              }
            end

            subject { update_epic(opts) }

            it_behaves_like 'syncs all data from an epic to a work item', notes_on_work_item: true

            context 'when updating rolledup dates' do
              let(:opts) { { start_date_is_fixed: false, due_date_is_fixed: false } }

              context 'with issue milestone date roll up' do
                let_it_be(:milestone) do
                  create(:milestone, group: group, start_date: Date.new(2024, 2, 1), due_date: Date.new(2024, 2, 29))
                end

                before do
                  child_issue = create(:issue, milestone: milestone, project: create(:project, group: group))
                  create(:epic_issue, epic: epic, issue: child_issue)
                end

                context 'when updating only due date' do
                  let(:opts) { { due_date: 2.days.from_now.to_date } }

                  it 'syncs due date' do
                    subject

                    expect(work_item.dates_source.due_date).to eq(epic.end_date)
                    expect(work_item.dates_source.due_date).to eq(opts[:due_date].to_date)
                  end
                end

                context 'when date sourcing epic is changed' do
                  let_it_be(:child_epic) { create(:epic, group: group, parent: epic) }

                  let(:opts) { { due_date: 2.days.from_now.to_date } }

                  before do
                    epic.update!(due_date_sourcing_epic_id: child_epic.id, start_date_sourcing_epic_id: child_epic.id)

                    allow(epic).to receive(:previous_changes).and_return({
                      due_date_sourcing_epic_id: child_epic.id, start_date_sourcing_epic_id: child_epic.id
                    })
                  end

                  it 'sets date sourcing epic to the work item', :aggregate_failures do
                    subject

                    expect(work_item.dates_source.due_date_sourcing_work_item_id).to eq(child_epic.work_item.id)
                    expect(work_item.dates_source.start_date_sourcing_work_item_id).to eq(child_epic.work_item.id)
                  end
                end

                it 'sets rolledup dated for the work item', :aggregate_failures do
                  subject

                  epic.reload
                  work_item = epic.work_item

                  expect(epic.start_date_sourcing_milestone_id).to eq(milestone.id)
                  expect(epic.due_date_sourcing_milestone_id).to eq(milestone.id)
                  expect(epic.start_date).to eq(milestone.start_date)
                  expect(epic.start_date_is_fixed).to eq(false)
                  expect(epic.due_date).to eq(milestone.due_date)
                  expect(epic.due_date_is_fixed).to eq(false)

                  expect(work_item.dates_source.start_date_is_fixed).to eq(epic.start_date_is_fixed)
                  expect(work_item.dates_source.start_date_fixed).to eq(epic.start_date_fixed)
                  expect(work_item.dates_source.start_date).to eq(epic.start_date)
                  expect(work_item.dates_source.due_date).to eq(epic.due_date)
                  expect(work_item.dates_source.start_date_sourcing_milestone_id)
                    .to eq(epic.start_date_sourcing_milestone_id)
                  expect(work_item.dates_source.due_date_sourcing_milestone_id)
                    .to eq(epic.due_date_sourcing_milestone_id)
                end
              end

              context 'with child epic date roll up' do
                let_it_be(:child_epic) do
                  create(
                    :epic, :with_synced_work_item,
                    group: group,
                    parent: epic,
                    start_date: Date.new(2024, 3, 1),
                    end_date: Date.new(2024, 3, 31)
                  )
                end

                before do
                  child_epic.work_item.update!(start_date: child_epic.start_date, due_date: child_epic.end_date)
                end

                it 'sets rolledup dated for the work item', :aggregate_failures do
                  subject

                  epic.reload
                  work_item = epic.work_item

                  expect(epic.start_date_sourcing_epic_id).to eq(child_epic.id)
                  expect(epic.due_date_sourcing_epic_id).to eq(child_epic.id)
                  expect(epic.start_date).to eq(child_epic.start_date)
                  expect(epic.start_date_is_fixed).to eq(false)
                  expect(epic.due_date).to eq(child_epic.end_date)
                  expect(epic.due_date_is_fixed).to eq(false)

                  expect(work_item.dates_source.start_date_is_fixed).to eq(epic.start_date_is_fixed)
                  expect(work_item.dates_source.start_date_fixed).to eq(epic.start_date_fixed)
                  expect(work_item.dates_source.start_date).to eq(epic.start_date)
                  expect(work_item.dates_source.due_date).to eq(epic.due_date)
                  expect(work_item.dates_source.start_date_sourcing_work_item_id).to eq(child_epic.issue_id)
                  expect(work_item.dates_source.due_date_sourcing_work_item_id).to eq(child_epic.issue_id)
                end
              end
            end

            context 'with epic color' do
              let_it_be_with_reload(:epic) { create(:epic, group: group, color: '#ffffff') }

              let(:opts) { { color: ::Epic::DEFAULT_COLOR } }

              before do
                create(:color, work_item: epic.work_item, color: epic.color)
              end

              it_behaves_like 'syncs all data from an epic to a work item'
            end

            context 'description tasks' do
              context 'when marking a task as done' do
                let_it_be(:description) { '- [ ] Task' }
                let_it_be_with_reload(:epic) { create(:epic, :with_synced_work_item, group: group, description: description) }

                let(:opts) do
                  {
                    description: '- [x] Task',
                    update_task: {
                      index: 1,
                      checked: true,
                      line_source: '- [ ] Task',
                      line_number: 1
                    }
                  }
                end

                it_behaves_like 'syncs all data from an epic to a work item'

                it 'updates the task on the epic and the work item' do
                  subject

                  expect(epic.reload.description).to eq('- [x] Task')
                  expect(work_item.reload.description).to eq('- [x] Task')
                end

                context 'when saving to the work item fails' do
                  before do
                    allow(work_item).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)
                  end

                  it 'does not update the epic or the work item' do
                    expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
                      .with({
                        message: "Not able to update epic work item",
                        error_message: 'Record invalid',
                        group_id: group.id,
                        epic_id: epic.id
                      })

                    expect { subject }.to raise_error(ActiveRecord::RecordInvalid)

                    expect(epic.reload.description).to eq('- [ ] Task')
                    expect(work_item.reload.description).to eq('- [ ] Task')
                  end
                end
              end

              context 'when unchecking a task' do
                let_it_be(:description) { '- [x] Task' }
                let_it_be_with_reload(:epic) { create(:epic, :with_synced_work_item, group: group, description: description) }
                let(:opts) do
                  {
                    description: '- [ ] Task',
                    update_task: {
                      index: 1,
                      checked: false,
                      line_source: '- [x] Task',
                      line_number: 1
                    }
                  }
                end

                it_behaves_like 'syncs all data from an epic to a work item'

                it 'updates the task on the epic and the work item' do
                  subject

                  expect(epic.reload.description).to eq('- [ ] Task')
                  expect(work_item.reload.description).to eq('- [ ] Task')
                end
              end

              context 'when params are different than the epic attributes', :aggregate_failures do
                before do
                  epic.work_item.create_dates_source!(start_date: 3.days.ago, due_date: 3.days.from_now)
                  epic.work_item.create_color!(color: "#123123")
                  epic.update!(title: "Outdated title", color: "#aabbcc", due_date_fixed: 3.days.ago)
                end

                let(:opts) do
                  {
                    description: 'New description'
                  }
                end

                it 'only applies the changed params and updated_at' do
                  subject

                  expect(epic.reload.description).to eq('New description')
                  expect(work_item.reload.description).to eq('New description')
                  expect(work_item.updated_by).to eq(epic.updated_by)
                  expect(work_item.updated_at).to eq(epic.updated_at)
                  expect(work_item.title).not_to eq('Outdated title')
                  expect(work_item.color.color).not_to eq(epic.color)
                  expect(work_item.dates_source.due_date_fixed).not_to eq(epic.due_date_fixed)
                end
              end
            end

            context 'when updating labels' do
              let_it_be(:label_on_epic) { create(:group_label, group: group) }
              let_it_be(:label_on_epic_work_item) { create(:group_label, group: group) }
              let_it_be(:new_labels) { create_list(:group_label, 2, group: group) }

              before do
                epic.labels << label_on_epic
                epic.work_item.labels << label_on_epic_work_item
              end

              context 'and replacing labels with `label_ids` param' do
                let(:opts) { { label_ids: new_labels.map(&:id) } }
                let(:expected_labels) { new_labels }
                let(:expected_epic_own_labels) { new_labels }
                let(:expected_epic_work_item_own_labels) { [] }

                it_behaves_like 'syncs labels between epics and epic work items'
              end

              context 'and removing label assigned to epic' do
                let(:opts) { { add_label_ids: new_labels.map(&:id), remove_label_ids: [label_on_epic.id] } }
                let(:expected_labels) { [new_labels, label_on_epic_work_item].flatten }
                let(:expected_epic_own_labels) { [new_labels].flatten }
                let(:expected_epic_work_item_own_labels) { [label_on_epic_work_item] }

                it_behaves_like 'syncs labels between epics and epic work items'
              end

              context 'and removing label assigned to epic work item' do
                let(:opts) do
                  { add_label_ids: new_labels.map(&:id), remove_label_ids: [label_on_epic_work_item.id] }
                end

                let(:expected_labels) { [new_labels, label_on_epic].flatten }
                let(:expected_epic_own_labels) { [new_labels, label_on_epic].flatten }
                let(:expected_epic_work_item_own_labels) { [] }

                it_behaves_like 'syncs labels between epics and epic work items'
              end
            end
          end

          context 'when changes are invalid', :aggregate_failures do
            it 'does not propagate the title change to the work item' do
              expect { update_epic({ title: '' }) }.to not_change { work_item.reload }

              expect(work_item.reload).to be_valid
            end
          end
        end

        it 'does not propagate the update to the work item and resets the epic updates on an error' do
          allow_next_found_instance_of(::WorkItem) do |instance|
            allow(instance).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)
          end

          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: "Not able to update epic work item",
              error_message: 'Record invalid',
              group_id: group.id,
              epic_id: epic.id
            })

          expect { update_epic({ title: 'New title' }) }
            .to raise_error(ActiveRecord::RecordInvalid)
            .and not_change { work_item.reload }
            .and not_change { epic.reload }
        end
      end
    end
  end
end
