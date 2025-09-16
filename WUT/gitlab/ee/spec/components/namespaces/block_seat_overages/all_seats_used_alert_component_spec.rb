# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::BlockSeatOverages::AllSeatsUsedAlertComponent, type: :component, feature_category: :consumables_cost_management do
  include ReactiveCachingHelpers

  let_it_be(:current_user) { build(:user) }
  let_it_be(:namespace) { build(:group, namespace_settings: build(:namespace_settings, seat_control: :block_overages)) }

  let(:billable_members_count) { 2 }
  let(:permission_owner) { true }

  before do
    allow(namespace).to receive(:billable_members_count).and_return(billable_members_count)
    allow(Ability).to receive(:allowed?).with(current_user, :owner_access, namespace).and_return(permission_owner)

    build(:gitlab_subscription, namespace: namespace, plan_code: Plan::ULTIMATE, seats: 2)
  end

  describe '#render?' do
    subject { component.render? }

    before do
      allow(current_user).to receive(:dismissed_callout_for_group?).and_return(false)
    end

    context 'in a saas environment', :saas do
      context 'with a reactive cache hit' do
        before do
          synchronous_reactive_cache(namespace)
        end

        describe 'when user has dismissed alert' do
          before do
            allow(current_user).to receive(:dismissed_callout_for_group?).and_return(true)
          end

          it { is_expected.to be false }
        end

        describe 'when namespace has no paid plan' do
          before do
            build(:gitlab_subscription, namespace: namespace, plan_code: Plan::FREE)
          end

          it { is_expected.to be false }
        end

        describe 'when user is not a owner' do
          let(:permission_owner) { false }

          it { is_expected.to be false }
        end

        describe 'when block seats overages is disabled' do
          let_it_be(:namespace) { build(:group, namespace_settings: build(:namespace_settings, seat_control: :off)) }

          it { is_expected.to be false }
        end

        describe 'with no billable members' do
          let(:billable_members_count) { 0 }

          it { is_expected.to be false }
        end

        describe 'with more billable members than seats' do
          let(:billable_members_count) { 3 }

          it { is_expected.to be true }
        end

        describe 'when namespace is personal' do
          let_it_be(:namespace) { build(:user, :with_namespace).namespace }

          it { is_expected.to be false }
        end

        it { is_expected.to be true }
      end

      context 'with a reactive cache miss' do
        before do
          stub_reactive_cache(namespace, nil)
        end

        it { is_expected.to be false }
      end
    end
  end

  def component(context = namespace)
    described_class.new(context: context, content_class: '', current_user: current_user)
  end
end
