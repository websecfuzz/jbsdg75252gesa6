# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserPreference do
  let_it_be(:user) { create(:user) }

  let(:user_preference) { create(:user_preference, user: user) }

  shared_examples 'updates roadmap_epics_state' do |state|
    it 'saves roadmap_epics_state in user_preference' do
      user_preference.update!(roadmap_epics_state: state)

      expect(user_preference.reload.roadmap_epics_state).to eq(state)
    end
  end

  describe 'associations' do
    it 'belongs to default_add_on_assignment optionally' do
      is_expected.to belong_to(:default_duo_add_on_assignment)
                       .class_name('GitlabSubscriptions::UserAddOnAssignment')
                       .optional
    end
  end

  describe 'roadmap_epics_state' do
    context 'when set to open epics' do
      it_behaves_like 'updates roadmap_epics_state', Epic.available_states[:opened]
    end

    context 'when set to closed epics' do
      it_behaves_like 'updates roadmap_epics_state', Epic.available_states[:closed]
    end

    context 'when reset to all epics' do
      it_behaves_like 'updates roadmap_epics_state', nil
    end
  end

  describe '#eligible_duo_add_on_assignments', :saas do
    let_it_be(:groups) do
      create_list(:group_with_plan, 2, plan: :ultimate_plan)
    end

    let_it_be(:add_on_purchases) do
      [
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: groups.first),
        create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: groups.second)
      ]
    end

    let!(:eligible_user_assignments) do
      add_on_purchases.map do |add_on|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end
    end

    let!(:non_eligible_user_assignments) do
      [
        create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: nil),
        create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: groups.first)
      ]
    end

    it 'only retrieves eligible user assignments' do
      expect(user_preference.eligible_duo_add_on_assignments).to match_array(eligible_user_assignments)
    end
  end

  describe 'default_duo_add_on_assignment_id', :saas do
    let_it_be(:groups) do
      create_list(:group_with_plan, 2, plan: :ultimate_plan)
    end

    let_it_be(:add_on_purchases) do
      [
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: groups.first),
        create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: groups.second)
      ]
    end

    let!(:user_assignments) do
      add_on_purchases.map do |add_on|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end
    end

    let(:first_assignment_id) { user_assignments.first.id }
    let(:second_assignment_id) { user_assignments.second.id }

    context 'when default_duo_add_on_assignment_id has not changed?' do
      it 'does call #check_seat_for_default_duo_namespace' do
        expect(user_preference).not_to receive(:check_seat_for_default_duo_assigment).and_call_original

        user_preference.valid?
      end
    end

    context 'when default_duo_add_on_assignment_id has changed?' do
      it 'calls #check_seat_for_default_duo_namespace' do
        expect(user_preference).to receive(:check_seat_for_default_duo_assigment).and_call_original

        user_preference.default_duo_add_on_assignment_id = first_assignment_id
        user_preference.valid?
      end
    end

    context 'when a correct value is assigned' do
      it 'saves the value' do
        user_preference.default_duo_add_on_assignment_id = first_assignment_id
        user_preference.save!

        expect(user_preference.default_duo_add_on_assignment_id).to eql(first_assignment_id)
      end
    end

    context 'when the seat gets destroyed' do
      it 'nullifies default duo_add_on_assignment_id' do
        user_preference.default_duo_add_on_assignment_id = first_assignment_id
        user_preference.save!

        user_assignments.first.destroy!
        user_preference.reload

        expect(user_preference.default_duo_add_on_assignment_id).to be_nil
      end
    end

    context 'when default_duo_add_on_assignment_id is changed to assignment id with namespace attached' do
      it 'does not add any errors' do
        [first_assignment_id, second_assignment_id].each do |seat_id|
          user_preference.default_duo_add_on_assignment_id = seat_id
          user_preference.valid?

          expect(user_preference.errors[:default_duo_add_on_assignment_id]).to be_empty
        end
      end
    end

    context 'when default_duo_add_on_assignment_id is changed to non_existing_id' do
      it 'does add an errors' do
        user_preference.default_duo_add_on_assignment_id = non_existing_record_id
        user_preference.valid?

        expect(user_preference.errors[:default_duo_add_on_assignment_id])
          .to include("No Duo seat assignments with namespace found with ID #{non_existing_record_id}")
      end
    end

    context 'when the assigment is not associated with a namespace' do
      let(:add_on_without_namespace) { create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: nil) }
      let(:user_assignment_id) do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_without_namespace, user: user).id
      end

      it 'does add an errors' do
        user_preference.default_duo_add_on_assignment_id = user_assignment_id
        user_preference.valid?

        expect(user_preference.errors[:default_duo_add_on_assignment_id])
          .to include("No Duo seat assignments with namespace found with ID #{user_assignment_id}")
      end
    end

    context 'when the assigment is not for a duo add on' do
      let(:non_duo_add_on) { create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: groups.first) }
      let(:user_assignment_id) do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: non_duo_add_on, user: user).id
      end

      it 'does add an errors' do
        user_preference.default_duo_add_on_assignment_id = user_assignment_id
        user_preference.valid?

        expect(user_preference.errors[:default_duo_add_on_assignment_id])
          .to include("No Duo seat assignments with namespace found with ID #{user_assignment_id}")
      end
    end
  end
end
