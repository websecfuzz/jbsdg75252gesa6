# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Epics::IssuePromoteService, :aggregate_failures, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:ancestor) { create(:group) }
  let_it_be(:group) { create(:group, parent: ancestor) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:label1) { create(:group_label, group: group) }
  let_it_be(:label2) { create(:label, project: project) }
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:description) { 'simple description' }
  let_it_be_with_refind(:issue) do
    create(
      :issue,
      project: project,
      labels: [label1, label2],
      milestone: milestone,
      description: description,
      weight: 3
    )
  end

  let_it_be_with_refind(:parent_epic) do
    create(:epic, group: group)
  end

  subject { described_class.new(container: issue.project, current_user: user) }

  let(:epic) { Epic.last }

  describe '#execute' do
    context 'when epics are not enabled' do
      it 'raises a permission error' do
        group.add_developer(user)

        expect { subject.execute(issue) }
          .to raise_error(Epics::IssuePromoteService::PromoteError, /permissions/)
      end
    end

    context 'when epics and subepics are enabled' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when a user can not promote the issue' do
        it 'raises a permission error' do
          expect { subject.execute(issue) }
            .to raise_error(Epics::IssuePromoteService::PromoteError, /permissions/)
        end
      end

      context 'when a user can promote the issue' do
        let(:new_group) { create(:group) }

        before do
          group.add_developer(user)
          new_group.add_developer(user)
        end

        context 'when an issue does not belong to a group' do
          it 'raises an error' do
            other_issue = create(:issue, project: create(:project))

            expect { subject.execute(other_issue) }
              .to raise_error(Epics::IssuePromoteService::PromoteError, /group/)
          end
        end

        context 'with published event' do
          it 'publishes an WorkItemCreatedEvent' do
            expect { subject.execute(issue) }
              .to publish_event(WorkItems::WorkItemCreatedEvent)
                    .with({ id: an_instance_of(Integer), namespace_id: group.id })
          end
        end

        it 'counts a usage ping event' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_issue_promoted_to_epic)
                                                                              .with(author: user, namespace: group)

          subject.execute(issue)
        end

        context 'when the issue belongs to an epic' do
          let_it_be(:epic_issue) { create(:epic_issue, :with_parent_link, epic: parent_epic, issue: issue) }

          it 'schedules update of cached metadata for the epic' do
            expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([epic_issue.epic_id]).once

            subject.execute(issue)
          end
        end

        context 'when promoting issue', :snowplow do
          let_it_be(:issue_mentionable_note) { create(:note, noteable: issue, author: user, project: project, note: "note with mention #{user.to_reference}") }
          let_it_be(:issue_note) { create(:note, noteable: issue, author: user, project: project, note: "note without mention") }

          let(:new_description) { "New description" }

          before do
            issue.update!(description: new_description)
            subject.execute(issue)
          end

          it 'creates a new epic with correct attributes' do
            expect(epic.title).to eq(issue.title)
            expect(epic.description).to eq(issue.description)
            expect(epic.author).to eq(user)
            expect(epic.group).to eq(group)
            expect(epic.parent).to be_nil
          end

          it 'copies group labels assigned to the issue' do
            expect(epic.labels).to eq([label1])
          end

          it 'creates a system note on the issue' do
            expect(issue.notes.last.note).to eq("promoted to epic #{epic.to_reference(project)}")
          end

          it 'creates a system note on the epic' do
            expect(epic.notes.last.note).to eq("promoted from issue #{issue.to_reference(group)}")
          end

          it 'closes the original issue' do
            expect(issue).to be_closed
          end

          it 'marks the old issue as promoted' do
            expect(issue).to be_promoted
            expect(issue.promoted_to_epic).to eq(epic)
          end

          it 'emits a snowplow event' do
            expect_snowplow_event(
              category: 'epics',
              action: 'promote',
              property: 'issue_id',
              value: issue.id,
              project: project,
              user: user,
              namespace: group,
              weight: 3
            )
          end

          context 'when issue description has mentions and has notes with mentions' do
            let(:new_description) { "description with mention to #{user.to_reference}" }

            it 'only saves user mentions with actual mentions' do
              expect(epic.user_mentions.find_by(note_id: nil).mentioned_users_ids).to match_array([user.id])
              expect(epic.user_mentions.where.not(note_id: nil).first.mentioned_users_ids).to match_array([user.id])
              expect(epic.user_mentions.where.not(note_id: nil).count).to eq 1
              expect(epic.user_mentions.count).to eq 2
            end
          end

          context 'when issue description has an attachment' do
            let(:image_uploader) { build(:file_uploader, container: project) }
            let(:new_description) { "A description and image: #{image_uploader.markdown_link}" }

            it 'copies the description, rewriting the attachment' do
              new_image_uploader = Upload.last.retrieve_uploader

              expect(new_image_uploader.markdown_link).not_to eq(image_uploader.markdown_link)
              expect(epic.description).to eq("A description and image: #{new_image_uploader.markdown_link}")
            end
          end
        end

        context 'when issue has resource label events' do
          let!(:label_event1) { create(:resource_label_event, label: label1, issue: issue, user: user) }
          let!(:label_event2) { create(:resource_label_event, label: label2, issue: issue, user: user) }

          it 'creates new label events on the epic that do not reference the original issue' do
            expect do
              subject.execute(issue)
              # 2 copied and 1 created automatically when an Epic work item is created on the background
            end.to change { ResourceLabelEvent.count }.by(3)

            expect(issue.resource_label_events.count).to eq(2)
            # Not using resource_label_events association because of WorkItems::UnifiedAssociations
            expect(ResourceLabelEvent.where(epic: epic).count).to eq(2)
            expect(
              ResourceLabelEvent.where(epic: epic).pluck(:epic_id, :issue_id)
            ).to contain_exactly([epic.id, nil], [epic.id, nil])
          end
        end

        context 'when issue has resource state event' do
          let_it_be(:issue_event) { create(:resource_state_event, issue: issue) }

          it 'does not raise error' do
            expect { subject.execute(issue) }.not_to raise_error
          end

          it 'creates a close state event for promoted issue' do
            # promote issue to epic also copies over existing issue state resource events to the epic
            # so in this case we have an existing resource event defined above and one that we create
            # for issue close event, which we are not copying over
            expect { subject.execute(issue) }.to change(ResourceStateEvent, :count).by(2).and(
              change(ResourceStateEvent.where(issue_id: issue), :count).by(1)
            )
          end

          it 'promotes issue successfully' do
            epic = subject.execute(issue)

            resource_state_event = epic.resource_state_events.first
            expect(epic.title).to eq(issue.title)
            expect(issue.promoted_to_epic).to eq(epic)
            expect(resource_state_event.issue_id).to eq(nil)
            expect(resource_state_event.epic_id).to eq(epic.id)
            expect(resource_state_event.state).to eq(issue_event.state)
          end
        end

        context 'when promoting issue to a different group' do
          it 'creates a new epic with correct attributes' do
            epic = subject.execute(issue, new_group)

            expect(issue.reload.promoted_to_epic_id).to eq(epic.id)
            expect(epic.title).to eq(issue.title)
            expect(epic.description).to eq(issue.description)
            expect(epic.author).to eq(user)
            expect(epic.group).to eq(new_group)
            expect(epic.parent).to be_nil
          end
        end

        context 'when an issue belongs to an epic' do
          let_it_be(:epic_issue) do
            create(:epic_issue, :with_parent_link, epic: parent_epic, issue: issue)
          end

          shared_examples 'successfully promotes issue to epic' do
            it 'creates a new epic with correct attributes' do
              epic = subject.execute(issue, new_group)

              expect(issue.reload.promoted_to_epic_id).to eq(epic.id)
              expect(epic.title).to eq(issue.title)
              expect(epic.description).to eq(issue.description)
              expect(epic.author).to eq(user)
              expect(epic.group).to eq(new_group)
              expect(epic.parent).to eq(parent_epic)
              expect(epic.work_item.work_item_parent).to eq(parent_epic.work_item)
            end
          end

          it_behaves_like 'successfully promotes issue to epic' do
            let(:new_group) { group }
          end

          context 'when promoting issue to a different group' do
            let_it_be(:new_group) { create(:group) }

            before do
              new_group.add_developer(user)
            end

            it_behaves_like 'successfully promotes issue to epic'
          end

          context 'when promoting issue to a different group in the same hierarchy' do
            context 'when the group is a descendant group' do
              let_it_be(:issue_group) { create(:group, parent: group) }

              before do
                new_group.add_developer(user)
              end

              it_behaves_like 'successfully promotes issue to epic'
            end

            context 'when the group is an ancestor group' do
              let(:new_group) { ancestor }

              before do
                new_group.add_developer(user)
              end

              it_behaves_like 'successfully promotes issue to epic'
            end
          end

          context 'when issue and epic are confidential' do
            before do
              issue.update_attribute(:confidential, true)
              parent_epic.update_attribute(:confidential, true)
              parent_epic.work_item.update_attribute(:confidential, true)
            end

            it 'promotes issue to epic' do
              epic = subject.execute(issue, group)

              expect(issue.reload.promoted_to_epic_id).to eq(epic.id)
              expect(epic.confidential).to eq(true)
              expect(epic.parent).to eq(parent_epic)
            end
          end

          context 'when subepics are disabled' do
            before do
              stub_licensed_features(epics: true, subepics: false)
            end

            it 'does not promote to epic and raises error' do
              expect { subject.execute(issue, new_group) }
                .to raise_error(Epics::IssuePromoteService::PromoteError, /No matching epic found/)

              expect(issue.reload.state).to eq("opened")
              expect(issue.reload.promoted_to_epic_id).to be_nil
            end
          end
        end

        context 'when issue was already promoted' do
          it 'raises error' do
            epic = create(:epic, group: group)
            issue.update!(promoted_to_epic_id: epic.id)

            expect { subject.execute(issue) }
              .to raise_error(Epics::IssuePromoteService::PromoteError, /already promoted/)
          end
        end

        context 'when issue has notes', :snowplow do
          before do
            issue.reload
          end

          it 'copies all notes' do
            discussion = create(:discussion_note_on_issue, noteable: issue, project: issue.project)

            epic = subject.execute(issue)
            expect(epic.notes.count).to eq(issue.notes.count)
            expect(epic.notes.where(discussion_id: discussion.discussion_id).count).to eq(0)
            expect(issue.notes.where(discussion_id: discussion.discussion_id).count).to eq(1)
            expect_snowplow_event(
              category: 'epics',
              action: 'promote',
              property: 'issue_id',
              value: issue.id,
              project: project,
              user: user,
              namespace: group,
              weight: 3
            )
          end
        end

        context 'on other issue types' do
          shared_examples_for 'raising error' do
            before do
              issue.update!(work_item_type: WorkItems::Type.default_by_type(issue_type))
            end

            it 'raises error' do
              expect { subject.execute(issue) }
                .to raise_error(Epics::IssuePromoteService::PromoteError, /is not supported/)
            end
          end

          context 'on an incident' do
            let(:issue_type) { :incident }

            it_behaves_like 'raising error'
          end

          context 'on a test case' do
            let(:issue_type) { :test_case }

            it_behaves_like 'raising error'
          end
        end

        context 'for synced work items' do
          let_it_be(:epic_issue) do
            create(:epic_issue, :with_parent_link, epic: parent_epic, issue: issue)
          end

          subject(:promote_issue) { described_class.new(container: issue.project, current_user: user).execute(issue) }

          it 'creates a work item' do
            expect { promote_issue }.to change { issue.project.group.work_items.count }.by(1)
          end

          context 'with synced data' do
            it 'writes notes and labels to the work item' do
              # A note "promoted from issue ..." will be added to the epic until
              # https://gitlab.com/gitlab-org/gitlab/-/issues/497510 is addressed
              expect { promote_issue }.to change { LabelLink.where(target_type: 'Issue').count }.by(1)
                .and not_change { LabelLink.where(target_type: 'Epic').count }
                .and change { Note.where(noteable_type: 'Issue').count }.by(3)
                .and change { Note.where(noteable_type: 'Epic').count }.by(1)
            end
          end
        end

        context 'for milestones' do
          let_it_be(:project_milestone) { create(:milestone, project: project) }

          it 'successfully retains the group level Milestone on the new epic' do
            epic = subject.execute(issue, group)
            expect(WorkItem.find(epic.issue_id).milestone).to eq(milestone)
          end

          it 'does not retain project level milestones on the new epic' do
            issue.milestone = project_milestone
            epic = subject.execute(issue, group)
            expect(WorkItem.find(epic.issue_id).milestone).to be_nil
          end
        end
      end
    end
  end
end
