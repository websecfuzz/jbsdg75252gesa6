# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::GroupsController, feature_category: :organization do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public, organization: organization) }

  describe 'DELETE #destroy' do
    subject(:gitlab_request) { delete groups_organization_path(organization, id: group.to_param) }

    before_all do
      group.add_owner(user)
    end

    context 'when authenticated user can admin the group' do
      before do
        sign_in(user)
      end

      context 'when subscription is linked to the group', :saas do
        let_it_be(:group) do
          create(:group_with_plan, plan: :ultimate_plan, owners: user, organization: organization)
        end

        it 'returns active subscription error' do
          gitlab_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq(_('This group is linked to a subscription'))
        end
      end
    end

    context 'when authenticated user cannot admin the group' do
      before do
        sign_in(create(:user))
      end

      it 'returns 404' do
        gitlab_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the group does not exist in the organization' do
      let_it_be(:other_organization) { create(:organization) }
      let_it_be(:group) { create(:group, :public, owners: user, organization: other_organization) }

      before do
        sign_in(user)
      end

      it_behaves_like 'organization - not found response'
    end
  end
end
