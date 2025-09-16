# frozen_string_literal: true

require 'spec_helper'

ADD_ONS = {
  duo_enterprise: { name: 3, description: 'Add-on for Gitlab Duo Enterprise.' },
  duo_core: { name: 5, description: 'Add-on for Gitlab Duo Core.' }
}.freeze

BACKFILL_PURCHASE_XID = 'duo_core_backfill_2025'
DEFAULT_TRIAL_QUANTITY = 10_000
GRACE_PERIOD = 14.days.freeze
UNLIMITED_SUBSCRIPTION_LENGTH = 5.years.freeze

# rubocop:disable RSpec/MultipleMemoizedHelpers -- those `let!` are necessary for test setup
RSpec.describe Gitlab::BackgroundMigration::BackfillDuoCoreForExistingSubscription, feature_category: :subscription_management do
  # Database tables
  let!(:organizations) { table(:organizations) }
  let!(:plans) { table(:plans) }
  let!(:add_ons) { table(:subscription_add_ons) }
  let!(:namespaces) { table(:namespaces) }
  let!(:gitlab_subscriptions) { table(:gitlab_subscriptions) }
  let!(:add_on_purchases) { table(:subscription_add_on_purchases) }

  # Organization setup
  let!(:organization) { organizations.create!(name: 'organization', path: 'organization') }

  # Plans setup
  let!(:plans_hash) { create_plans }
  let!(:default_plan) { plans_hash[:default] }
  let!(:bronze_plan) { plans_hash[:bronze] }
  let!(:silver_plan) { plans_hash[:silver] }
  let!(:premium_plan) { plans_hash[:premium] }
  let!(:gold_plan) { plans_hash[:gold] }
  let!(:ultimate_plan) { plans_hash[:ultimate] }
  let!(:ultimate_trial_plan) { plans_hash[:ultimate_trial] }
  let!(:ultimate_trial_paid_customer_plan) { plans_hash[:ultimate_trial_paid_customer] }
  let!(:premium_trial_plan) { plans_hash[:premium_trial] }
  let!(:opensource_plan) { plans_hash[:opensource] }
  let!(:free_plan) { plans_hash[:free] }

  # Add-ons setup
  let!(:add_ons_hash) { create_add_ons }
  let!(:duo_enterprise_add_on) { add_ons_hash[:duo_enterprise] }
  let!(:duo_core_add_on) { add_ons_hash[:duo_core] }

  # Namespaces, Gitlab subscriptions, and AddOnPurchase setup
  let!(:root_group_1) { create_namespace('root-group-1') }
  let!(:gs_1_paid_ultimate) do
    create_subscription(root_group_1.id, ultimate_plan.id, seats: 111)
  end

  let!(:root_group_2) { create_namespace('root-group-2') }
  let!(:gs_2_trial_ultimate) do
    create_subscription(
      root_group_2.id,
      ultimate_trial_plan.id,
      seats: 0,
      trial: true,
      trial_starts_on: Date.current - 1.month,
      trial_ends_on: Date.current + 11.months
    )
  end

  let!(:root_user_group) { create_namespace('root-user-group', type: 'User') }
  let!(:gs_user_paid_ultimate) do
    create_subscription(root_user_group.id, ultimate_plan.id, seats: 333)
  end

  let!(:root_group_4) { create_namespace('root-group-4') }
  let!(:gs_4_paid_ultimate_end_date_null) do
    create_subscription(root_group_4.id, ultimate_plan.id, seats: 444, end_date: nil)
  end

  let!(:root_group_5) { create_namespace('root-group-5') }
  let!(:gs_5_paid_premium) do
    create_subscription(root_group_5.id, premium_plan.id, seats: 555, end_date: Date.current)
  end

  let!(:sub_group) { create_namespace('sub', parent_id: root_group_1.id) }
  let!(:gs_sub) do
    create_subscription(sub_group.id, ultimate_plan.id, seats: 666)
  end

  let!(:root_group_7) { create_namespace('root-group-7') }
  let!(:gs_7_paid_bronze_start_date_null) do
    create_subscription(root_group_7.id, bronze_plan.id, seats: 777, start_date: nil)
  end

  let!(:root_group_8) { create_namespace('root-group-8') }
  let!(:gs_8_paid_gold) do
    create_subscription(root_group_8.id, gold_plan.id, seats: 888)
  end

  let!(:root_group_9) { create_namespace('root-group-9') }
  let!(:gs_9_paid_silver) do
    create_subscription(root_group_9.id, silver_plan.id, seats: 999)
  end

  # Migration setup
  let(:migration_args) do
    {
      batch_table: :gitlab_subscriptions,
      batch_column: :id,
      sub_batch_size: sub_batch_size,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  let!(:duo_core_add_on_purchases) { add_on_purchases.where(subscription_add_on_id: duo_core_add_on.id) }
  let(:sub_batch_size) { 1 }

  subject(:migration) { described_class.new(**migration_args) }

  RSpec.shared_examples 'creates Duo Core add-on purchase' do
    it "creates add-on purchase" do
      migration.perform

      expect(duo_core_add_on_purchases.where(namespace_id: namespace.id).count).to eq(1)

      add_on_purchase = duo_core_add_on_purchases.where(namespace_id: namespace.id).first
      expect(add_on_purchase).to have_attributes(
        subscription_add_on_id: duo_core_add_on.id,
        quantity: quantity,
        started_at: started_at,
        expires_on: expires_on,
        purchase_xid: BACKFILL_PURCHASE_XID,
        trial: false,
        organization_id: namespace.organization_id
      )
    end
  end

  describe '#perform' do
    context 'when running the migration' do
      it 'creates the expected number of add-on purchases' do
        expect(duo_core_add_on_purchases.count).to eq(0)

        migration.perform

        expect(duo_core_add_on_purchases.count).to eq(7)
      end

      include_examples 'creates Duo Core add-on purchase' do
        let!(:namespace) { root_group_1 }
        let(:quantity) { gs_1_paid_ultimate.seats }
        let(:started_at) { gs_1_paid_ultimate.start_date }
        let(:expires_on) { gs_1_paid_ultimate.end_date + GRACE_PERIOD }
      end

      include_examples 'creates Duo Core add-on purchase' do
        let!(:namespace) { root_group_2 }
        let(:quantity) { DEFAULT_TRIAL_QUANTITY }
        let(:started_at) { gs_2_trial_ultimate.trial_starts_on }
        let(:expires_on) { gs_2_trial_ultimate.trial_ends_on }
      end

      include_examples 'creates Duo Core add-on purchase' do
        let!(:namespace) { root_group_4 }
        let(:quantity) { gs_4_paid_ultimate_end_date_null.seats }
        let(:started_at) { gs_4_paid_ultimate_end_date_null.start_date }
        let(:expires_on) { Date.current + UNLIMITED_SUBSCRIPTION_LENGTH + GRACE_PERIOD }
      end

      include_examples 'creates Duo Core add-on purchase' do
        let!(:namespace) { root_group_5 }
        let(:quantity) { gs_5_paid_premium.seats }
        let(:started_at) { gs_5_paid_premium.start_date }
        let(:expires_on) { gs_5_paid_premium.end_date + GRACE_PERIOD }
      end

      include_examples 'creates Duo Core add-on purchase' do
        let!(:namespace) { root_group_7 }
        let(:quantity) { gs_7_paid_bronze_start_date_null.seats }
        let(:started_at) { Date.current }
        let(:expires_on) { gs_7_paid_bronze_start_date_null.end_date + GRACE_PERIOD }
      end

      include_examples 'creates Duo Core add-on purchase' do
        let!(:namespace) { root_group_8 }
        let(:quantity) { gs_8_paid_gold.seats }
        let(:started_at) { gs_8_paid_gold.start_date }
        let(:expires_on) { gs_8_paid_gold.end_date + GRACE_PERIOD }
      end

      include_examples 'creates Duo Core add-on purchase' do
        let!(:namespace) { root_group_9 }
        let(:quantity) { gs_9_paid_silver.seats }
        let(:started_at) { gs_9_paid_silver.start_date }
        let(:expires_on) { gs_9_paid_silver.end_date + GRACE_PERIOD }
      end
    end

    context 'with different batch sizes' do
      let(:sub_batch_size) { 3 }

      it 'processes all eligible subscriptions' do
        migration.perform

        expect(duo_core_add_on_purchases.count).to eq(7)
      end
    end

    context 'when skipping ineligible subscriptions' do
      it 'skips user namespaces' do
        migration.perform

        expect(duo_core_add_on_purchases.where(namespace_id: root_user_group.id).count).to eq(0)
      end

      it 'skips sub-group subscriptions' do
        migration.perform

        expect(duo_core_add_on_purchases.where(namespace_id: sub_group.id).count).to eq(0)
      end

      context 'when the group already has a Duo Core add-on purchase' do
        before do
          add_on_purchases.create!(
            subscription_add_on_id: duo_core_add_on.id,
            namespace_id: root_group_1.id,
            quantity: gs_1_paid_ultimate.seats + 100,
            started_at: gs_1_paid_ultimate.start_date - 2.days,
            expires_on: gs_1_paid_ultimate.end_date + 3.days,
            purchase_xid: 'purchase_xid',
            organization_id: organization.id
          )
        end

        it 'does not change existing Duo Core add-on purchase' do
          expect(duo_core_add_on_purchases.count).to eq(1)

          expect { migration.perform }
            .to not_change { duo_core_add_on_purchases.where(namespace_id: root_group_1.id).first.attributes }

          expect(duo_core_add_on_purchases.count).to eq(7)
        end
      end

      context 'when the group already has duo_enterprise add-on-purchase record' do
        before do
          add_on_purchases.create!(
            subscription_add_on_id: duo_enterprise_add_on.id,
            namespace_id: root_group_1.id,
            quantity: gs_1_paid_ultimate.seats + 100,
            started_at: gs_1_paid_ultimate.start_date - 2.days,
            expires_on: gs_1_paid_ultimate.end_date + 3.days,
            purchase_xid: 'purchase_xid',
            organization_id: organization.id
          )
        end

        include_examples 'creates Duo Core add-on purchase' do
          let!(:namespace) { root_group_1 }
          let(:quantity) { gs_1_paid_ultimate.seats }
          let(:started_at) { gs_1_paid_ultimate.start_date }
          let(:expires_on) { gs_1_paid_ultimate.end_date + GRACE_PERIOD }
        end
      end

      it 'skips the duo_core creation for ineligible plan' do
        [default_plan, free_plan].each do |ineligible_plan|
          gs_1_paid_ultimate.update!(hosted_plan_id: ineligible_plan.id)

          migration.perform

          expect(duo_core_add_on_purchases.where(namespace_id: root_group_1.id)).not_to be_exists
        end
      end

      it 'skips the duo_core creation for expired subscription' do
        gs_1_paid_ultimate.update!(end_date: Date.yesterday)

        migration.perform

        expect(duo_core_add_on_purchases.where(namespace_id: root_group_1.id)).not_to be_exists
      end
    end
  end

  # Helper methods
  def create_plans
    plan_definitions = {
      default: %w[default Default],
      bronze: %w[bronze Bronze],
      silver: %w[silver Silver],
      premium: %w[premium Premium],
      gold: %w[gold Gold],
      ultimate: %w[ultimate Ultimate],
      ultimate_trial: ['ultimate_trial', 'Ultimate Trial'],
      ultimate_trial_paid_customer: ['ultimate_trial_paid_customer', 'Ultimate Trial Paid Customer'],
      premium_trial: ['premium_trial', 'Premium Trial'],
      opensource: %w[opensource Opensource],
      free: ['free', nil]
    }

    plan_definitions.transform_values do |name, title|
      plans.create!(name: name, title: title)
    end
  end

  def create_add_ons
    {
      duo_enterprise: add_ons.create!(name: ADD_ONS[:duo_enterprise][:name],
        description: ADD_ONS[:duo_enterprise][:description]),
      duo_core: add_ons.create!(name: ADD_ONS[:duo_core][:name], description: ADD_ONS[:duo_core][:description])
    }
  end

  def create_namespace(name, type: 'Group', **attrs)
    namespaces.create!({
      name: name,
      path: name,
      type: type,
      organization_id: organization.id
    }.merge(attrs))
  end

  def create_subscription(namespace_id, plan_id, seats: 100, trial: false, **attrs)
    gitlab_subscriptions.create!({
      namespace_id: namespace_id,
      start_date: Date.current - 1.month,
      end_date: Date.current + 11.months,
      trial: trial,
      trial_starts_on: nil,
      trial_ends_on: nil,
      hosted_plan_id: plan_id,
      seats: seats
    }.merge(attrs))
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
