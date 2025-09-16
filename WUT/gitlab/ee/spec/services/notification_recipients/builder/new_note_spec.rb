# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NotificationRecipients::Builder::NewNote, feature_category: :team_planning do
  describe '#notification_recipients' do
    let_it_be(:group) { create(:group, :public) }
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:epic_work_item_as_issue) { Issue.find(epic.issue_id) }

    let_it_be(:participant) { create(:user) }
    let_it_be(:non_member_participant) { create(:user) }
    let_it_be(:group_watcher) { create(:user) }
    let_it_be(:guest_group_watcher) { create(:user) }
    let_it_be(:subscriber) { create(:user) }
    let_it_be(:unsubscribed_user) { create(:user) }
    let_it_be(:non_member_subscriber) { create(:user) }

    let_it_be(:notification_setting_guest_w) do
      create(:notification_setting, source: group, user: guest_group_watcher, level: 2)
    end

    let_it_be(:notification_setting_group_w) do
      create(:notification_setting, source: group, user: group_watcher, level: 2)
    end

    let_it_be(:subscriptions) do
      [
        create(:subscription, project: nil, user: subscriber, subscribable: epic, subscribed: true),
        create(:subscription, project: nil, user: unsubscribed_user, subscribable: epic, subscribed: false),
        create(:subscription, project: nil, user: non_member_subscriber, subscribable: epic, subscribed: true)
      ]
    end

    subject(:notification_recipients_builder) { described_class.new(note) }

    before_all do
      group.add_developer(participant)
      group.add_guest(guest_group_watcher)
      group.add_developer(subscriber)
      group.add_developer(group_watcher)
    end

    before do
      stub_licensed_features(epics: true)

      allow(epic).to receive(:participants).and_return([participant, non_member_participant])
      allow(epic_work_item_as_issue).to receive(:participants).and_return([participant, non_member_participant])
    end

    context 'for legacy epic' do
      context 'for public notes' do
        let_it_be(:note) { create(:note_on_epic, noteable: epic) }

        it 'adds all participants, watchers and subscribers' do
          expect(notification_recipients_builder.notification_recipients.map(&:user)).to contain_exactly(
            participant, non_member_participant, group_watcher, guest_group_watcher, subscriber, non_member_subscriber
          )
        end
      end

      context 'for confidential notes' do
        let_it_be(:note) { create(:note_on_epic, :confidential, noteable: epic) }

        it 'adds all participants, watchers and subscribers that are group members' do
          expect(notification_recipients_builder.notification_recipients.map(&:user)).to contain_exactly(
            participant, group_watcher, subscriber
          )
        end
      end
    end

    context 'for epic work item' do
      context 'for public notes' do
        let_it_be(:note) { create(:note_on_epic, noteable: epic_work_item_as_issue) }

        it 'adds all participants, watchers and subscribers' do
          expect(notification_recipients_builder.notification_recipients.map(&:user)).to contain_exactly(
            participant, non_member_participant, group_watcher, guest_group_watcher, subscriber, non_member_subscriber
          )
        end
      end

      context 'for confidential notes' do
        let_it_be(:note) { create(:note_on_epic, :confidential, noteable: epic_work_item_as_issue) }

        it 'adds all participants, watchers and subscribers that are group members' do
          expect(notification_recipients_builder.notification_recipients.map(&:user)).to contain_exactly(
            participant, group_watcher, subscriber
          )
        end
      end
    end
  end
end
