# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials, feature_category: :subscription_management do
  describe '.single_eligible_namespace?' do
    subject { described_class.single_eligible_namespace?(eligible_namespaces) }

    context 'when there are multiple namespaces' do
      let(:eligible_namespaces) { build_list(:namespace, 2) }

      it { is_expected.to be(false) }
    end

    context 'when there is one namespace' do
      let(:eligible_namespaces) { [build(:namespace)] }

      it { is_expected.to be(true) }
    end

    context 'when there are no namespaces' do
      let(:eligible_namespaces) { [] }

      it { is_expected.to be(false) }
    end
  end

  describe '.eligible_namespace?' do
    context 'when namespace_id is blank' do
      it 'returns true for nil' do
        expect(described_class.eligible_namespace?(nil, [])).to be(true)
      end

      it 'returns true for empty string' do
        expect(described_class.eligible_namespace?('', [])).to be(true)
      end
    end

    context 'when namespace_id is present' do
      let_it_be(:namespace) { create(:group) }
      let(:eligible_namespaces) { Namespace.id_in(namespace.id) }

      it 'returns true for an eligible namespace' do
        expect(described_class.eligible_namespace?(namespace.id.to_s, eligible_namespaces)).to be(true)
      end

      it 'returns false for an in-eligible namespace' do
        expect(described_class.eligible_namespace?(non_existing_record_id.to_s, eligible_namespaces)).to be(false)
      end
    end
  end

  describe '.creating_group_trigger?' do
    subject { described_class.creating_group_trigger?(namespace_id) }

    where(:namespace_id, :expected_result) do
      [
        [0,   true],
        [nil, false],
        [1,   false]
      ]
    end

    with_them do
      it { is_expected.to be(expected_result) }
    end
  end

  describe '.namespace_eligible?', :saas, :use_clean_rails_memory_store_caching do
    let(:trial_types) { described_class::TRIAL_TYPES }
    let_it_be(:namespace) { create(:group) }

    before do
      Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", trial_types)
    end

    subject { described_class.namespace_eligible?(namespace) }

    context 'with a plan that is eligible for a trial' do
      where(plan: ::Plan::PLANS_ELIGIBLE_FOR_TRIAL)

      with_them do
        let(:namespace) { create(:group_with_plan, plan: "#{plan}_plan") }

        it { is_expected.to be(true) }
      end
    end

    context 'with a plan that is ineligible for a trial' do
      where(plan: ::Plan::PAID_HOSTED_PLANS.without(::Plan::PREMIUM))

      with_them do
        let(:namespace) { create(:group_with_plan, plan: "#{plan}_plan") }

        it { is_expected.to be(false) }
      end
    end

    context 'with namespace that is ineligible for a trial due to trial_types' do
      let(:trial_types) { ['gitlab_duo_pro'] }

      it { is_expected.to be(false) }
    end
  end

  describe '.namespace_plan_eligible_for_active?', :saas do
    subject { described_class.namespace_plan_eligible_for_active?(namespace) }

    context 'with a plan that is on a trial' do
      where(plan: ::Plan::ULTIMATE_TRIAL_PLANS)

      with_them do
        let(:namespace) { create(:group_with_plan, plan: "#{plan}_plan") }

        it { is_expected.to be(true) }
      end
    end

    context 'with a plan that is not on a trial' do
      where(plan: ::Plan::PAID_HOSTED_PLANS.without(::Plan::ULTIMATE_TRIAL_PLANS))

      with_them do
        let(:namespace) { create(:group_with_plan, plan: "#{plan}_plan") }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '.namespace_add_on_eligible?', :use_clean_rails_memory_store_caching do
    let(:trial_types) { [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE] }
    let_it_be(:namespace) { create(:group) }

    before do
      Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", trial_types)
    end

    subject(:execute) { described_class.namespace_add_on_eligible?(namespace) }

    it { is_expected.to be(true) }

    context 'when ineligible' do
      let(:trial_types) { ['gitlab_duo_pro'] }

      it { is_expected.to be(false) }
    end
  end

  describe '.eligible_namespaces_for_user', :use_clean_rails_memory_store_caching do
    let(:trial_types) { [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE] }
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }

    before do
      Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", trial_types)
    end

    subject(:execute) { described_class.eligible_namespaces_for_user(user) }

    it { is_expected.to eq([namespace]) }

    context 'when ineligible' do
      let(:trial_types) { ['gitlab_duo_pro'] }

      it { is_expected.to be_empty }
    end
  end

  describe '.namespace_with_mid_trial_premium?', :saas do
    let_it_be(:free_namespace) { create(:group) }
    let_it_be(:premium_namespace) { create(:group_with_plan, plan: :premium_plan) }

    let(:namespace) { premium_namespace }

    subject(:execute) { described_class.namespace_with_mid_trial_premium?(namespace, Date.current) }

    context 'when with mid-trial premium history record' do
      before do
        create(
          :gitlab_subscription_history, :update,
          namespace: namespace, hosted_plan: premium_namespace.actual_plan
        )
      end

      it { is_expected.to be(true) }

      context 'when namespace is on a free plan' do
        let(:namespace) { free_namespace }

        it { is_expected.to be(false) }
      end
    end

    context 'when without mid-trial premium history record' do
      before do
        create(
          :gitlab_subscription_history, :update,
          namespace: free_namespace, hosted_plan: premium_namespace.actual_plan
        )
      end

      it { is_expected.to be(false) }
    end
  end
end
