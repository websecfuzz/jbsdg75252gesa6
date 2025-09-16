# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Provision::SyncNamespaceService, :aggregate_failures, feature_category: :plan_provisioning do
  describe '#execute' do
    let_it_be(:ultimate_plan) { create(:ultimate_plan) }
    let_it_be_with_reload(:namespace) { create(:group) }
    let_it_be(:start_date) { Date.current.to_s }
    let_it_be(:end_date) { 1.year.from_now.to_date.to_s }

    let(:params) { {} }

    subject(:result) { described_class.new(namespace: namespace, params: params).execute }

    it 'returns success' do
      expect(namespace).not_to receive(:update)

      expect(result).to be_success
    end

    context 'when syncing base product' do
      let(:params) do
        {
          base_product: {
            plan_code: 'ultimate',
            seats: 30,
            start_date: start_date,
            end_date: end_date,
            max_seats_used: 10,
            auto_renew: true,
            trial: false,
            trial_starts_on: nil,
            trial_ends_on: nil
          }
        }
      end

      it 'creates a new gitlab_subscription record with the given plan for the namespace' do
        expect { result }.to change { GitlabSubscription.where(namespace: namespace).count }.from(0).to(1)

        expect(namespace.reload.gitlab_subscription).to have_attributes(
          seats: 30,
          start_date: Date.parse(start_date),
          end_date: Date.parse(end_date),
          max_seats_used: 10,
          auto_renew: true,
          trial: false,
          trial_starts_on: nil,
          trial_ends_on: nil
        )
        expect(namespace.gitlab_subscription.plan_name).to eq('ultimate')
      end

      context 'when gitlab_subscription already exists' do
        before do
          create(:premium_trial_plan)
          namespace.create_gitlab_subscription!(
            plan_code: 'premium_trial',
            trial: true,
            trial_starts_on: start_date,
            trial_ends_on: 1.month.from_now.to_date.to_s
          )
        end

        it 'updates the existing gitlab_subscription record' do
          expect { result }.to change { namespace.reload.gitlab_subscription.plan_name }
            .from('premium_trial').to('ultimate')

          expect(namespace.reload.gitlab_subscription).to have_attributes(
            seats: 30,
            start_date: Date.parse(start_date),
            end_date: Date.parse(end_date),
            max_seats_used: 0, # resets after update to paid plan
            auto_renew: true,
            trial: false,
            trial_starts_on: nil,
            trial_ends_on: nil
          )
        end
      end

      context 'when invalid record params are sent' do
        let(:params) { { base_product: { seats: nil } } }

        it 'returns error response' do
          expect(result).to be_error
          expect(result.message).to match(/subscription seats can't be blank/)
        end
      end
    end

    context 'when syncing storage' do
      let(:storage_params) do
        {
          additional_purchased_storage_size: 10_000,
          additional_purchased_storage_ends_on: end_date
        }
      end

      before do
        params[:storage] = storage_params
      end

      it 'updates the storage attributes for the namespace' do
        expect { result }.to change { namespace.reload.eligible_additional_purchased_storage_size }.to(10_000)
          .and change { namespace.reload.additional_purchased_storage_ends_on }.to(Date.parse(end_date))
      end

      context 'when invalid record params are sent' do
        let(:storage_params) { { additional_purchased_storage_size: nil } }

        it 'returns error response' do
          expect(result).to be_error
          expect(result.message).to match(/purchased storage size can't be blank/)
        end
      end
    end

    context 'when syncing compute minutes' do
      let_it_be_with_reload(:namespace) do
        create(
          :group,
          :with_ci_minutes,
          ci_minutes_used: 1000,
          extra_shared_runners_minutes_limit: 400
        )
      end

      before do
        params[:compute_minutes] = compute_minutes_params
      end

      context 'when updating the extra shared runners minutes limit' do
        let(:compute_minutes_params) { { extra_shared_runners_minutes_limit: 100 } }

        it 'updates the extra_shared_runners_minutes_limit value' do
          expect { result }.to change { namespace.reload.extra_shared_runners_minutes_limit }.from(400).to(100)
        end
      end

      context 'when updating the shared runners minutes limit' do
        let(:compute_minutes_params) { { shared_runners_minutes_limit: 200 } }

        it 'updates the shared_runners_minutes_limit value' do
          expect { result }.to change { namespace.reload.shared_runners_minutes_limit }.to(200)
        end
      end

      context 'when compute minutes parmas is not set' do
        let(:compute_minutes_params) { {} }

        it 'returns success' do
          expect(GitlabSubscriptions::Provision::SyncComputeMinutesService).not_to receive(:new)

          expect(result).to be_success
        end
      end

      context 'when syncing compute minutes fails' do
        let(:compute_minutes_params) { { extra_shared_runners_minutes_limit: 100 } }

        it 'returns error response with message' do
          expect_next_instance_of(GitlabSubscriptions::Provision::SyncComputeMinutesService) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Validation failed'))
          end

          expect(result).to be_error
          expect(result.message).to match(/Validation failed/)
        end
      end
    end

    context 'when syncing add-on purchases' do
      let(:purchase_xid) { 'S-A00000001' }

      let(:params) do
        {
          add_on_purchases:
          {
            duo_pro: [{
              started_on: start_date,
              expires_on: end_date,
              purchase_xid: purchase_xid,
              quantity: 1,
              trial: false
            }],
            product_analytics: [{
              started_on: start_date,
              expires_on: end_date,
              purchase_xid: purchase_xid,
              quantity: 1,
              trial: false
            }]
          }
        }
      end

      it 'provisions add-ons correctly' do
        expect do
          expect(result).to be_success
        end.to change { GitlabSubscriptions::AddOnPurchase.count }.from(0).to(2)

        expect(namespace.subscription_add_on_purchases.for_gitlab_duo_pro.first).to have_attributes(
          started_at: Date.parse(start_date),
          expires_on: Date.parse(end_date),
          purchase_xid: purchase_xid,
          quantity: 1,
          trial: false
        )
        expect(namespace.subscription_add_on_purchases.for_product_analytics.first).to have_attributes(
          started_at: Date.parse(start_date),
          expires_on: Date.parse(end_date),
          purchase_xid: purchase_xid,
          quantity: 1,
          trial: false
        )
      end

      context 'when syncing add on purchases fails' do
        it 'returns error response with message' do
          expect_next_instance_of(::GitlabSubscriptions::AddOnPurchases::GitlabCom::ProvisionService) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Validation failed'))
          end

          expect(result).to be_error
          expect(result.message).to match(/Validation failed/)
        end
      end
    end

    context 'when all provision params are provided' do
      let(:params) do
        {
          base_product: {
            plan_code: 'ultimate',
            seats: 30,
            start_date: start_date,
            end_date: end_date,
            auto_renew: true,
            trial: false
          },
          storage: {
            additional_purchased_storage_size: 100
          },
          compute_minutes: {
            extra_shared_runners_minutes_limit: 90
          },
          add_on_purchases: {
            duo_enterprise: [{
              started_on: start_date,
              expires_on: end_date,
              purchase_xid: 'A-S00001',
              quantity: 1,
              trial: false
            }],
            product_analytics: [{
              started_on: start_date,
              expires_on: end_date,
              purchase_xid: 'A-S00001',
              quantity: 1,
              trial: false
            }]
          }
        }
      end

      it 'returns success and provisions the namespace with correct attributes' do
        expect(result).to be_success

        expect(namespace.reload.gitlab_subscription.plan_name).to eq('ultimate')
        expect(namespace.additional_purchased_storage_size).to eq(100)
        expect(namespace.extra_shared_runners_minutes_limit).to eq(90)
        expect(namespace.subscription_add_on_purchases.uniq_add_on_names)
          .to match_array(%w[duo_enterprise product_analytics])
      end

      context 'when any provisioning fails' do
        context 'when base product provisioning fails' do
          before do
            params[:base_product][:seats] = nil
          end

          it 'continues with provisioning the rest with valid attributes' do
            expect do
              expect(result).to be_error
              expect(result.message).to match(/subscription seats can't be blank/)
            end.not_to change { namespace.reload.gitlab_subscription }

            expect(namespace.additional_purchased_storage_size).to eq(100)
            expect(namespace.extra_shared_runners_minutes_limit).to eq(90)
          end
        end

        context 'when storage provisioning fails' do
          before do
            params[:storage][:additional_purchased_storage_size] = nil
          end

          it 'continues with provisioning the rest with valid attributes' do
            expect do
              expect(result).to be_error
              expect(result.message).to match(/purchased storage size can't be blank/)
            end.not_to change { namespace.reload.additional_purchased_storage_size }

            expect(namespace.reload.gitlab_subscription.plan_name).to eq('ultimate')
            expect(namespace.extra_shared_runners_minutes_limit).to eq(90)
          end
        end

        context 'when compute minutes provisioning fails' do
          it 'continues with provisioning the rest with valid attributes' do
            expect_next_instance_of(GitlabSubscriptions::Provision::SyncComputeMinutesService) do |service|
              expect(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Validation failed'))
            end

            expect do
              expect(result).to be_error
              expect(result.message).to match(/Validation failed/)
            end.not_to change { namespace.reload.extra_shared_runners_minutes_limit }

            expect(namespace.reload.gitlab_subscription.plan_name).to eq('ultimate')
            expect(namespace.additional_purchased_storage_size).to eq(100)
          end
        end

        context 'when add-on purchases provisioning fails' do
          it 'continues with provisioning the rest with valid attributes' do
            expect_next_instance_of(::GitlabSubscriptions::AddOnPurchases::GitlabCom::ProvisionService) do |service|
              expect(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Validation failed'))
            end

            expect do
              expect(result).to be_error
              expect(result.message).to match(/Validation failed/)
            end.not_to change { namespace.subscription_add_on_purchases.count }

            expect(namespace.reload.gitlab_subscription.plan_name).to eq('ultimate')
            expect(namespace.additional_purchased_storage_size).to eq(100)
            expect(namespace.extra_shared_runners_minutes_limit).to eq(90)
          end
        end
      end
    end
  end
end
