# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_security_labels custom role', feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:role) { create(:member_role, :reporter, :admin_security_labels, namespace: group) }
  let_it_be(:membership) { create(:group_member, :reporter, member_role: role, user: user, group: group) }

  before do
    stub_licensed_features(custom_roles: true, security_labels: true)

    sign_in(user)
  end

  describe "Controllers endpoints" do
    describe Groups::Security::ConfigurationController do
      it 'can access the show endpoint' do
        get group_security_configuration_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
