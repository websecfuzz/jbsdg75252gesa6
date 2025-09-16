# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionHistory, :saas, feature_category: :seat_cost_management do
  let_it_be(:group1) { create(:group_with_plan, plan: :premium_plan) }
  let_it_be(:group2) { create(:group_with_plan, plan: :premium_plan) }
  let_it_be(:free_plan) { create(:free_plan) }

  it { is_expected.to belong_to(:hosted_plan).class_name('Plan').inverse_of(:gitlab_subscription_histories) }

  describe 'relation to a namespace' do
    let_it_be(:history1) { create(:gitlab_subscription_history, namespace: group1) }
    let_it_be(:history2) { create(:gitlab_subscription_history, namespace: group2) }

    it { is_expected.to belong_to(:namespace).required }

    it 'returns histories for the given namespace' do
      expect(described_class.all).to match_array([history1, history2])
      expect(group1.gitlab_subscription_histories).to match_array([history1])
      expect(group2.gitlab_subscription_histories).to match_array([history2])
    end
  end

  describe 'scopes' do
    describe '.transitioning_to_plan_after' do
      let(:plan) { group1.actual_plan }
      let(:date) { 2.days.ago }

      subject(:transitioning_to_plan_after) do
        described_class.transitioning_to_plan_after(plan, date)
      end

      context 'when change_type is updated' do
        let_it_be(:subscription_history) do
          create(
            :gitlab_subscription_history, :update,
            namespace: group1, hosted_plan: group1.actual_plan, created_at: 1.day.ago
          )
        end

        it { expect(transitioning_to_plan_after).to eq([subscription_history]) }

        context 'when plan is different' do
          let(:plan) { free_plan }

          it { expect(transitioning_to_plan_after).to eq([]) }
        end

        context 'when created_at is before the date' do
          let(:date) { Date.current }

          it { expect(transitioning_to_plan_after).to eq([]) }
        end
      end

      context 'when change_type is destroyed' do
        before do
          create(
            :gitlab_subscription_history, :destroyed,
            namespace: group1, hosted_plan: group1.actual_plan, created_at: 1.day.ago
          )
        end

        it { expect(transitioning_to_plan_after).to eq([]) }
      end
    end
  end

  describe '.create_from_change' do
    context 'when supplied an invalid change type' do
      it 'raises an error' do
        expect do
          described_class.create_from_change(
            :invalid_change_type,
            { 'id' => 1 }
          )
        end.to raise_error(ArgumentError, "'invalid_change_type' is not a valid change_type")
      end
    end

    context 'when the required attributes are not present' do
      it 'returns an error when gitlab_subscription_id is not present' do
        record = described_class.create_from_change(
          :gitlab_subscription_updated,
          { 'id' => nil, 'namespace_id' => 2 }
        )

        expect(record.errors.attribute_names).to include(:gitlab_subscription_id)
      end

      it 'returns an error when namespace is not present' do
        record = described_class.create_from_change(
          :gitlab_subscription_updated,
          { 'id' => 1, 'namespace_id' => nil }
        )

        expect(record.errors.full_messages).to include("Namespace must exist")
      end

      it 'returns an error when namespace does not exist' do
        record = described_class.create_from_change(
          :gitlab_subscription_updated,
          {
            'id' => 1,
            'namespace_id' => non_existing_record_id,
            'seats_in_use' => 10,
            'trial' => true,
            'seats' => 15
          }
        )

        expect(record.errors.full_messages).to include("Namespace must exist")
      end
    end

    context 'when supplied extra attributes than exist on the history table' do
      it 'saves the tracked attributes without error' do
        current_time = Time.current

        record = described_class.create_from_change(
          :gitlab_subscription_updated,
          {
            'id' => 1,
            'namespace_id' => group1.id,
            'created_at' => current_time,
            'updated_at' => current_time,
            'non_existent_attribute' => true,
            'seats_in_use' => 10,
            'trial' => true,
            'seats' => 15
          }
        )

        expect(record).to be_valid
        expect(record).to be_persisted

        expect(record).to have_attributes(
          'gitlab_subscription_id' => 1,
          'namespace_id' => group1.id,
          'gitlab_subscription_created_at' => current_time,
          'gitlab_subscription_updated_at' => current_time,
          'seats_in_use' => 10,
          'trial' => true,
          'seats' => 15
        )

        expect(record.attributes.keys).to include(*GitlabSubscriptions::SubscriptionHistory::TRACKED_ATTRIBUTES)

        expect(record.attributes.keys).not_to include(
          'non_existent_attribute',
          *GitlabSubscriptions::SubscriptionHistory::OMITTED_ATTRIBUTES
        )
      end
    end
  end
end
