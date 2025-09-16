# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::GroupsController, feature_category: :subscription_management do
  let_it_be(:user) { create(:user) }

  describe 'GET #new' do
    context 'with an unauthenticated user' do
      subject(:get_new) do
        get new_gitlab_subscriptions_group_path, params: { plan_id: 'plan-id' }
        response
      end

      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'with an authenticated user' do
      subject(:get_new) do
        get new_gitlab_subscriptions_group_path, params: { plan_id: 'plan-id' }
        response
      end

      before do
        sign_in(user)
      end

      context 'when the plan cannot be found' do
        before do
          allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
            allow(instance).to receive(:execute).and_return([])
          end
        end

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when the user does not have existing namespaces' do
        let(:plan_data) { { id: 'plan-id' } }

        before do
          allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
            allow(instance).to receive(:execute).and_return([plan_data])
          end
        end

        it { is_expected.to render_template 'layouts/minimal' }
        it { is_expected.to render_template :new }
        it { is_expected.to have_gitlab_http_status(:ok) }

        it 'assigns the eligible groups for the subscription' do
          get_new

          expect(assigns(:eligible_groups)).to be_empty
        end

        it 'assigns the plan data' do
          get_new

          expect(assigns(:plan_data)).to eq plan_data
        end
      end

      context 'when the user has existing namespaces' do
        let(:plan_data) { { id: 'plan-id' } }

        let_it_be(:owned_group) { create(:group) }
        let_it_be(:maintainer_group) { create(:group) }
        let_it_be(:developer_group) { create(:group) }

        before_all do
          owned_group.add_owner(user)
          maintainer_group.add_maintainer(user)
          developer_group.add_developer(user)
        end

        before do
          allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
            allow(instance).to receive(:execute).and_return([plan_data])
          end

          allow_next_instance_of(
            GitlabSubscriptions::FetchPurchaseEligibleNamespacesService,
            user: user,
            namespaces: [owned_group],
            plan_id: 'plan-id'
          ) do |instance|
            allow(instance).to receive(:execute).and_return(
              instance_double(ServiceResponse, success?: true, payload: [{ namespace: owned_group, account_id: nil }])
            )
          end
        end

        it { is_expected.to render_template 'layouts/minimal' }
        it { is_expected.to render_template :new }
        it { is_expected.to have_gitlab_http_status(:ok) }

        it 'assigns the eligible groups for the subscription' do
          get_new

          expect(assigns(:eligible_groups)).to match_array [owned_group]
        end

        it 'assigns the plan data' do
          get_new

          expect(assigns(:plan_data)).to eq plan_data
        end
      end
    end
  end

  describe 'POST #create', :with_current_organization do
    subject(:post_create) do
      post gitlab_subscriptions_groups_path, params: params
      response
    end

    let(:params) { { group: { name: 'Test Group' }, plan_id: 'plan-id' } }

    context 'with an unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'with an authenticated user' do
      before do
        sign_in(user)
        current_organization.users << user
      end

      context 'with valid params' do
        context 'when no path is provided' do
          it 'creates a new group' do
            expect { post_create }.to change { user.groups.count }.from(0).to(1)
            expect(response).to have_gitlab_http_status(:created)
            expect(json_response).to eq('id' => user.groups.last.id)
            expect(user.groups.last.name).to eq('Test Group')
          end
        end

        context 'when path is provided' do
          let(:params) { { group: { name: 'Test Group', path: 'test-group123' } } }

          it 'creates a new group' do
            expect { post_create }.to change { user.groups.count }.from(0).to(1)
            expect(response).to have_gitlab_http_status(:created)
            expect(json_response).to eq('id' => user.groups.last.id)
            expect(user.groups.last.name).to eq('Test Group')
            expect(user.groups.last.path).to eq('test-group123')
          end
        end
      end

      context 'when a namespace already exists with the same name' do
        let(:params) { { group: { name: 'Test Group' } } }

        it 'creates the group with a different path' do
          create(:group, name: 'Test Group', path: 'test-group')

          expect { post_create }.to change { user.groups.count }.from(0).to(1)
          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to eq('id' => user.groups.last.id)
        end
      end

      context 'with invalid params' do
        let(:params) { { group: { name: '' }, plan_id: 'plan-id' } }

        it 'has the unprocessable entity status and the errors' do
          post_create

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response).to match(
            'errors' => {
              "name" => array_including("can't be blank")
            }
          )
        end
      end
    end
  end

  describe 'GET #edit' do
    let_it_be(:group) { create(:group, :public) }

    subject(:get_new) do
      get edit_gitlab_subscriptions_group_path(id: group.to_param)
      response
    end

    context 'with an unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'with an authenticated user who is not an owner' do
      before do
        sign_in(user)
      end

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'with an authenticated user' do
      before_all do
        group.add_owner(user)
      end

      before do
        sign_in(user)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      context 'when there is an old group path used' do
        before_all do
          create(:redirect_route, source: group, path: 'old-path')
        end

        subject do
          get edit_gitlab_subscriptions_group_path(id: 'old-path')
          response
        end

        it { is_expected.to have_gitlab_http_status(:redirect) }
        it { is_expected.to redirect_to(edit_gitlab_subscriptions_group_path(group)) }
      end
    end
  end

  describe 'PUT #update' do
    let_it_be(:group) { create(:group, :public) }
    let(:params) { { name: 'New name', path: 'new-path' } }

    subject(:put_update) do
      put gitlab_subscriptions_group_path(id: group.to_param), params: { group: params }
      response
    end

    context 'with an unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to(new_user_session_path) }

      it 'does not update the name' do
        expect { put_update }.not_to change { group.reload.name }
      end

      it 'does not update the path' do
        expect { put_update }.not_to change { group.reload.path }
      end

      context 'for visibility change' do
        let(:params) { { visibility_level: Gitlab::VisibilityLevel::PRIVATE } }

        it 'does not update visibility' do
          expect { put_update }.not_to change { group.reload.visibility_level }
        end
      end
    end

    context 'with an authenticated user who is not a group owner' do
      before do
        sign_in(user)
      end

      it { is_expected.to have_gitlab_http_status(:not_found) }

      it 'does not update the name' do
        expect { put_update }.not_to change { group.reload.name }
      end

      it 'does not update the path' do
        expect { put_update }.not_to change { group.reload.path }
      end

      context 'for visibility change' do
        let(:params) { { visibility_level: Gitlab::VisibilityLevel::PRIVATE } }

        it 'does not update visibility' do
          expect { put_update }.not_to change { group.reload.visibility_level }
        end
      end
    end

    context 'with an authenticated user' do
      let(:params) { { name: 'New name', path: 'new-path', visibility_level: Gitlab::VisibilityLevel::PRIVATE } }

      before_all do
        group.add_owner(user)
      end

      before do
        sign_in(user)
      end

      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to('/new-path') }

      it 'updates the name' do
        expect { put_update }.to change { group.reload.name }.to('New name')
      end

      it 'updates the path' do
        expect { put_update }.to change { group.reload.path }.to('new-path')
      end

      it 'updates the visibility_level' do
        expect do
          put_update
        end.to change { group.reload.visibility_level }.from(Gitlab::VisibilityLevel::PUBLIC)
                                                       .to(Gitlab::VisibilityLevel::PRIVATE)
      end

      it 'sets flash notice' do
        put_update

        expect(flash[:notice]).to include('Subscription successfully applied to "New name"')
      end

      context 'with new_user param' do
        subject(:put_update) do
          put gitlab_subscriptions_group_path(id: group.to_param), params: { group: params, new_user: 'true' }
          response
        end

        it 'sets flash notice' do
          put_update

          expect(flash[:notice]).to include("Welcome to GitLab, #{user.first_name}!")
        end
      end
    end

    context 'when the group cannot be saved' do
      before_all do
        group.add_owner(user)
      end

      before do
        sign_in(user)
      end

      let(:params) { { name: '', path: '' } }

      it 'does not update the name' do
        expect { put_update }.not_to change { group.reload.name }
      end

      it 'does not update the path' do
        expect { put_update }.not_to change { group.reload.path }
      end

      it { is_expected.to have_gitlab_http_status(:ok) }
      it { is_expected.to render_template(:edit) }
      it { is_expected.to render_template 'layouts/checkout' }
    end
  end
end
