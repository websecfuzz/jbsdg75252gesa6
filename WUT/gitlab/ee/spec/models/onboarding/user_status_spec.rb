# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::UserStatus, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  context 'for delegations' do
    subject { described_class.new(nil) }

    it { is_expected.to delegate_method(:product_interaction).to(:registration_type) }
    it { is_expected.to delegate_method(:apply_trial?).to(:registration_type) }
    it { is_expected.to delegate_method(:eligible_for_iterable_trigger?).to(:registration_type) }
  end

  describe '#registration_type' do
    where(:registration_type, :expected_klass) do
      'free'         | ::Onboarding::FreeRegistration
      nil            | ::Onboarding::FreeRegistration
      'trial'        | ::Onboarding::TrialRegistration
      'invite'       | ::Onboarding::InviteRegistration
      'subscription' | ::Onboarding::SubscriptionRegistration
    end

    with_them do
      let(:current_user) do
        build(
          :user,
          onboarding_status_initial_registration_type: registration_type,
          onboarding_status_registration_type: registration_type
        )
      end

      specify do
        expect(described_class.new(current_user).registration_type).to eq expected_klass
      end
    end

    context 'when user is nil' do
      it 'defaults to a free registration' do
        expect(described_class.new(nil).registration_type).to eq ::Onboarding::FreeRegistration
      end
    end

    context 'with automatic_trial concerns' do
      let(:current_user) do
        build(
          :user,
          onboarding_status_initial_registration_type: 'free',
          onboarding_status_registration_type: 'trial'
        )
      end

      it 'is an automatic trial' do
        expect(described_class.new(current_user).registration_type).to eq ::Onboarding::AutomaticTrialRegistration
      end

      context 'when it is not an automatic trial and has a mixed initial and current registration_type' do
        let(:current_user) do
          build(
            :user,
            onboarding_status_initial_registration_type: 'free',
            onboarding_status_registration_type: 'invite'
          )
        end

        it 'is not a trial registration' do
          expect(described_class.new(current_user).registration_type).to eq ::Onboarding::InviteRegistration
        end
      end
    end
  end

  describe '#existing_plan' do
    let(:registration_type) { 'invite' }
    let(:member) { build(:group_member) }
    let(:members) { [member] }
    let(:user) { build(:user, onboarding_status_registration_type: registration_type, members: members) }

    subject { described_class.new(user).existing_plan }

    it { is_expected.to eq({ existing_plan: 'default' }) }

    context 'when it is a free registration' do
      let(:registration_type) { 'free' }

      it { is_expected.to eq({}) }
    end

    context 'when there are no members' do
      let(:members) { [] }

      it { is_expected.to eq({}) }
    end

    context 'when there are multiple members it picks the last one' do
      let(:last_group) { build(:group) }
      let(:last_member) { build(:group_member, source: last_group) }
      let(:members) { [member, last_member] }

      before do
        allow(last_group).to receive(:actual_plan_name).and_return('ultimate')
      end

      it { is_expected.to eq({ existing_plan: 'ultimate' }) }
    end
  end
end
