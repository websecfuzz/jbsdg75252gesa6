# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Members::DestroyedWorker, feature_category: :seat_cost_management do
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:source) { create(:group, parent: root_namespace) }
  let_it_be(:user) { create(:user) }

  let(:root_namespace_id) { root_namespace.id }
  let(:source_id) { source.id }
  let(:source_type) { source.class.name }
  let(:user_id) { user.id }

  let(:members_destroyed_event) do
    ::Members::DestroyedEvent.new(
      data: {
        root_namespace_id: root_namespace_id,
        source_id: source_id,
        source_type: source_type,
        user_id: user_id
      }
    )
  end

  it_behaves_like 'subscribes to event' do
    let(:event) { members_destroyed_event }
  end

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#handle_event' do
    let_it_be(:seat_assignment) { create(:gitlab_subscription_seat_assignment, namespace: root_namespace, user: user) }

    it 'destroys SeatAssignment record' do
      expect do
        consume_event(subscriber: described_class, event: members_destroyed_event)
      end.to change { GitlabSubscriptions::SeatAssignment.where(namespace: root_namespace, user: user).count }.by(-1)
    end

    context 'when there is no seat assignment record related to user' do
      let(:user_id) { create(:user).id }

      it "does not destroy others' seat_assignment records" do
        expect do
          consume_event(subscriber: described_class, event: members_destroyed_event)
        end.not_to change { GitlabSubscriptions::SeatAssignment.count }
      end
    end

    shared_examples 'returns early' do
      specify do
        expect(GitlabSubscriptions::SeatAssignment).not_to receive(:find_by_namespace_and_user)

        expect do
          consume_event(subscriber: described_class, event: members_destroyed_event)
        end.not_to change { GitlabSubscriptions::SeatAssignment.count }
      end
    end

    context 'when user is not found' do
      let(:user_id) { non_existing_record_id }

      it_behaves_like 'returns early'
    end

    context 'when root namespace is not found' do
      let(:root_namespace_id) { non_existing_record_id }

      it_behaves_like 'returns early'
    end

    context 'when root namespace is not group' do
      let(:user_namespace) { create(:user_namespace) }
      let(:root_namespace_id) { user_namespace.id }

      it_behaves_like 'returns early'
    end

    context 'when user is still a member of group hierarchy' do
      let(:another_sub_group) { create(:group, parent: root_namespace) }

      before do
        another_sub_group.add_guest(user)
      end

      it_behaves_like 'returns early'

      context 'when the user is blocked' do
        before do
          user.block!
        end

        it_behaves_like 'returns early'
      end
    end

    context 'when user is still a member of project hierarchy' do
      let(:project) { build(:project, group: root_namespace) }

      before do
        project.add_guest(user)
      end

      it_behaves_like 'returns early'
    end
  end
end
