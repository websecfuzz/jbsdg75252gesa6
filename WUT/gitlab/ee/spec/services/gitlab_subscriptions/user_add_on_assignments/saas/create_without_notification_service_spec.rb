# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UserAddOnAssignments::Saas::CreateWithoutNotificationService, feature_category: :seat_cost_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }
  let_it_be(:user) { create(:user, developer_of: namespace) }

  subject(:response) do
    described_class.new(add_on_purchase: add_on_purchase, user: user).execute
  end

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
    ::Users::Internal.duo_code_review_bot # ensure interal user exists
  end

  describe '#execute' do
    let(:log_params) do
      {
        username: user.username,
        add_on: add_on_purchase.add_on.name,
        namespace: namespace.full_path
      }
    end

    shared_examples 'success response' do
      it 'creates new records' do
        expect(Gitlab::AppLogger).to receive(:info).with(log_params.merge(message: 'User AddOn assignment created'))

        expect { subject }.to change { add_on_purchase.assigned_users.where(user: user).count }.by(1)
        expect(response).to be_success
      end

      it 'expires the user add-on cache', :use_clean_rails_redis_caching do
        cache_key = user.duo_pro_cache_key_formatted
        Rails.cache.write(cache_key, false, expires_in: 1.hour)

        expect { subject }.to change { Rails.cache.read(cache_key) }.from(false).to(nil)
      end
    end

    shared_examples 'error response' do |error|
      it 'does not create new records' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          log_params.merge(
            {
              message: 'User AddOn assignment creation failed',
              error: error,
              error_code: 422
            }
          )
        )

        expect { subject }.not_to change { add_on_purchase.assigned_users.count }
        expect(response.errors).to include(error)
      end
    end

    shared_examples 'without notification' do
      it 'does not create an iterable trigger' do
        expect(::Onboarding::CreateIterableTriggerWorker).not_to receive(:perform_async)

        subject
      end
    end

    it_behaves_like 'success response'
    it_behaves_like 'without notification'

    context 'when user is already assigned' do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
      end

      it 'does not create new record' do
        expect { response }.not_to change { add_on_purchase.assigned_users.count }
        expect(response).to be_success
      end
    end

    context 'when seats are not available' do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: create(:user))
      end

      it_behaves_like 'error response', 'NO_SEATS_AVAILABLE'
    end

    context 'when user is not member of namespace' do
      let(:user) { create(:user) }

      it_behaves_like 'error response', 'INVALID_USER_MEMBERSHIP'
    end

    context 'when user has guest role' do
      let(:user) { namespace.add_guest(create(:user)).user }

      it_behaves_like 'success response'
    end

    context 'when user is member of subgroup' do
      let(:subgroup) { create(:group, parent: namespace) }
      let(:user) { subgroup.add_developer(create(:user)).user }

      it_behaves_like 'success response'
    end

    context 'when user is member of project' do
      let_it_be(:project) { create(:project, namespace: namespace) }
      let(:user) { project.add_developer(create(:user)).user }

      it_behaves_like 'success response'
    end

    context 'when user is member of shared group' do
      let(:invited_group) { create(:group) }
      let(:user) { invited_group.add_developer(create(:user)).user }

      before do
        create(:group_group_link, { shared_with_group: invited_group, shared_group: namespace })
      end

      it_behaves_like 'success response'
    end

    context 'when user is member of shared project' do
      let(:invited_group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let(:user) { invited_group.add_developer(create(:user)).user }

      before do
        create(:project_group_link, project: project, group: invited_group)
      end

      it_behaves_like 'success response'
    end

    context 'with resource locking' do
      before do
        add_on_purchase.update!(quantity: 1)
      end

      it 'prevents from double booking assignment' do
        users = create_list(:user, 3)

        expect(add_on_purchase.assigned_users.count).to eq(0)

        users.map do |user|
          namespace.add_developer(user)

          Thread.new do
            described_class.new(
              add_on_purchase: add_on_purchase,
              user: user
            ).execute
          end
        end.each(&:join)

        expect(add_on_purchase.assigned_users.count).to eq(1)
      end

      context 'when NoSeatsAvailableError is raised' do
        let(:service_instance) { described_class.new(add_on_purchase: add_on_purchase, user: user) }

        subject(:response) { service_instance.execute }

        it 'handles the error correctly' do
          # fill up the available seats
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase)

          # Mock first call to return true to pass the validate phase
          expect(service_instance).to receive(:seats_available?).and_return(true)
          expect(service_instance).to receive(:seats_available?).and_call_original

          expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
            an_instance_of(described_class::NoSeatsAvailableError),
            log_params.merge({ message: 'User AddOn assignment creation failed' })
          )

          expect { response }.not_to raise_error
          expect(response.errors).to include('NO_SEATS_AVAILABLE')
        end
      end
    end

    context 'with a Duo Enterprise add-on purchase' do
      let(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
      let(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }

      it_behaves_like 'success response'
      it_behaves_like 'without notification'
    end
  end
end
