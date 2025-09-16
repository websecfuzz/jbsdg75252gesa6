# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::VirtualRegistriesController, feature_category: :virtual_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  describe 'GET #index' do
    subject(:api_request) { get group_virtual_registries_path(group) }

    it { is_expected.to have_request_urgency(:low) }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      context 'when user is not a group member' do
        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is group member' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'returning response status', :ok

        it_behaves_like 'disallowed access to virtual registry'

        context 'when there are available registries' do
          let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group:) }

          it 'returns a successful response' do
            api_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(assigns(:registry_types_with_counts)).to eq(maven: 1)
          end
        end

        context 'when there are no available registries' do
          it 'handles empty registry counts' do
            api_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(assigns(:registry_types_with_counts)).to eq(maven: 0)
          end
        end
      end
    end
  end
end
