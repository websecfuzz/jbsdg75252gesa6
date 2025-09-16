# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::BillingsController, feature_category: :subscription_management do
  let_it_be(:owner) { create(:user) }
  let_it_be(:auditor) { create(:auditor) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    group.add_developer(developer)
    group.add_guest(auditor)
    group.add_owner(owner)
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  describe 'GET index' do
    def get_index
      get :index, params: { group_id: group }
    end

    subject { response }

    shared_examples 'authorized' do
      before do
        allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
          allow(instance).to receive(:execute).and_return([])
        end

        allow(controller).to receive(:track_experiment_event)
      end

      it 'renders index with 200 status code' do
        get_index

        is_expected.to have_gitlab_http_status(:ok)
        is_expected.to render_template(:index)
      end

      it 'fetches subscription plans data from customers.gitlab.com' do
        data = double
        expect_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
          expect(instance).to receive(:execute).and_return(data)
        end

        get_index

        expect(assigns(:plans_data)).to eq(data)
      end

      it_behaves_like 'seat count alert' do
        subject { get_index }

        let(:namespace) { group }
      end

      context 'when CustomersDot is unavailable' do
        before do
          allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
            allow(instance).to receive(:execute).and_return(nil)
          end
        end

        it 'renders a different partial' do
          get_index

          expect(response).to render_template('shared/billings/customers_dot_unavailable')
        end
      end
    end

    context 'auditor' do
      before do
        sign_in(auditor)
      end

      it_behaves_like 'authorized'
    end

    context 'owner' do
      before do
        sign_in(owner)
      end

      it_behaves_like 'authorized'
    end

    context 'unauthorized' do
      it 'renders 404 when user is not an owner' do
        sign_in(developer)

        get_index

        is_expected.to have_gitlab_http_status(:not_found)
      end

      it 'renders 404 when gitlab_com_subscriptions are not available' do
        stub_saas_features(gitlab_com_subscriptions: false)

        sign_in(owner)

        get_index

        is_expected.to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST refresh_seats', :saas do
    let_it_be(:gitlab_subscription) do
      create(:gitlab_subscription, namespace: group)
    end

    before do
      sign_in(owner)
    end

    subject(:post_refresh_seats) do
      post :refresh_seats, params: { group_id: group }
    end

    context 'authorized' do
      context 'with feature flag on' do
        it 'refreshes subscription seats' do
          # Developer and Owner users are added as billable users. Guests are not counted
          expect { post_refresh_seats }.to change { group.gitlab_subscription.reload.seats_in_use }.from(0).to(2)
        end

        it 'renders 200' do
          post_refresh_seats

          is_expected.to have_gitlab_http_status(:ok)
        end

        context 'when update fails' do
          before do
            allow_next_found_instance_of(GitlabSubscription) do |subscription|
              allow(subscription).to receive(:save).and_return(false)
            end
          end

          it 'renders 400' do
            post_refresh_seats

            is_expected.to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context 'with feature flag off' do
        before do
          stub_feature_flags(refresh_billings_seats: false)
        end

        it 'renders 400' do
          post_refresh_seats

          is_expected.to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'unauthorized' do
      it 'renders 404 when user is not an owner' do
        sign_in(developer)

        post_refresh_seats

        is_expected.to have_gitlab_http_status(:not_found)
      end

      it 'renders 404 when gitlab_com_subscriptions are not available' do
        stub_saas_features(gitlab_com_subscriptions: false)

        sign_in(owner)

        post_refresh_seats

        is_expected.to have_gitlab_http_status(:not_found)
      end
    end
  end
end
