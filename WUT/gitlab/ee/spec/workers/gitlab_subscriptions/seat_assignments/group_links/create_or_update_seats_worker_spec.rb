# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatAssignments::GroupLinks::CreateOrUpdateSeatsWorker, :saas, feature_category: :seat_cost_management do
  describe '.perform' do
    let_it_be(:group_a) { create(:group) }
    let_it_be_with_refind(:group_b) { create(:group) }
    let_it_be(:group_a_owner) { create(:user) }
    let_it_be(:group_b_owner) { create(:user) }
    let_it_be(:user) { create(:user) }

    subject(:worker) { described_class.new }

    before_all do
      group_a.add_owner(group_a_owner)
      group_b.add_owner(group_b_owner)
    end

    context 'when a group is invited to a group with an ultimate plan' do
      before_all do
        create(:gitlab_subscription, namespace: group_b, hosted_plan: create(:ultimate_plan))
      end

      let_it_be_with_refind(:link) { create(:group_group_link, shared_with_group: group_a, shared_group: group_b) }

      it_behaves_like 'an idempotent worker' do
        let(:job_args) { link.id }
      end

      it 'creates seat assignments in the shared group for each user in the invited group' do
        group_a.add_guest(user)

        worker.perform(link.id)

        group_a_owner_seat = group_b.subscription_seat_assignments.find_by!(user_id: group_a_owner.id)
        user_seat = group_b.subscription_seat_assignments.find_by!(user_id: user.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to include(group_a_owner.id, user.id)
        expect(group_a_owner_seat.seat_type).to eq('base')
        expect(user_seat.seat_type).to eq('free')
      end

      it 'creates seat assignments with a plan type' do
        group_a.add_planner(user)

        worker.perform(link.id)

        seat = group_b.subscription_seat_assignments.find_by!(user_id: user.id)

        expect(seat.seat_type).to eq('plan')
      end

      it 'sets the seat type based on both the group link access level and the member access level' do
        link.update!(group_access: ::Gitlab::Access::GUEST)

        worker.perform(link.id)

        seat = group_b.subscription_seat_assignments.find_by!(user_id: group_a_owner.id)

        expect(seat.seat_type).to eq('free')
      end

      it "does nothing if it doesn't find the group link" do
        worker.perform(non_existing_record_id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).not_to include(group_a_owner.id)
      end

      it 'upgrades the seat type if the new membership requires a higher seat' do
        seat = ::GitlabSubscriptions::SeatAssignment.create!(
          namespace: group_b,
          user: group_a_owner,
          organization_id: group_b.organization_id,
          seat_type: :free
        )

        worker.perform(link.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to include(group_a_owner.id)
        expect(seat.reload.seat_type).to eq('base')
      end

      it 'does not upgrade the seat type if the current seat is sufficient for the new membership' do
        group_a.add_guest(user)
        seat = ::GitlabSubscriptions::SeatAssignment.create!(
          namespace: group_b,
          user: user,
          organization_id: group_b.organization_id,
          seat_type: :free
        )

        worker.perform(link.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to include(user.id)
        expect(seat.reload.seat_type).to eq('free')
      end

      it 'does not downgrade the seat type if the existing seat is higher than what the new membership requires' do
        group_a.add_guest(user)
        seat = ::GitlabSubscriptions::SeatAssignment.create!(
          namespace: group_b,
          user: user,
          organization_id: group_b.organization_id,
          seat_type: :base
        )

        worker.perform(link.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to include(user.id)
        expect(seat.reload.seat_type).to eq('base')
      end
    end

    context 'when a group is invited to a group with a premium plan' do
      let_it_be_with_refind(:link) { create(:group_group_link, shared_with_group: group_a, shared_group: group_b) }

      before_all do
        create(:gitlab_subscription, namespace: group_b, hosted_plan: create(:premium_plan))
      end

      it 'upgrades the seat type if the new membership requires a higher seat' do
        group_a.add_guest(user)
        seat = ::GitlabSubscriptions::SeatAssignment.create!(
          namespace: group_b,
          user: user,
          organization_id: group_b.organization_id,
          seat_type: :free
        )

        worker.perform(link.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to include(user.id)
        expect(seat.reload.seat_type).to eq('base')
      end
    end

    context 'when a group is invited to a subgroup within another root group hierarchy' do
      let_it_be(:subgroup_b) { create(:group, parent: group_b) }
      let_it_be_with_refind(:link) { create(:group_group_link, shared_with_group: group_a, shared_group: subgroup_b) }

      it 'creates seat assignments for the shared group root ancestor' do
        worker.perform(link.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to include(group_a_owner.id)
      end
    end

    context 'when a subgroup is invited to another subgroup within the same hierarchy' do
      let_it_be(:subgroup_b1) { create(:group, parent: group_b) }
      let_it_be(:subgroup_b2) { create(:group, parent: group_b) }
      let_it_be_with_refind(:link) do
        create(:group_group_link, shared_with_group: subgroup_b1, shared_group: subgroup_b2)
      end

      before_all do
        subgroup_b1.add_developer(create(:user))
      end

      it 'does nothing' do
        worker.perform(link.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to be_empty
      end
    end
  end
end
