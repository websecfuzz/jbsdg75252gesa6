# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::AdminRoles::CreateService, feature_category: :permissions do
  let_it_be(:user) { create(:admin) }

  describe '#execute' do
    let(:abilities) { Gitlab::CustomRoles::Definition.admin.keys.sample(1).index_with(true) }

    let(:params) do
      {
        name: role_name
      }.merge(abilities)
    end

    let(:role_name) { 'doggfather' }
    let(:role_class) { Authz::AdminRole }

    subject(:create_role) { described_class.new(user, params).execute }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'with admin_mode disabled' do
      let(:error_message) { 'Operation not allowed' }

      it_behaves_like 'custom role create service returns error'
    end

    context 'when admin_mode is enabled', :enable_admin_mode do
      context 'when creating an admin custom role' do
        it_behaves_like 'custom role creation' do
          let(:fail_condition!) do
            allow(Ability).to receive(:allowed?).and_return(false)
          end

          let(:audit_event_message) { 'Admin role was created' }
          let(:audit_event_type) { 'admin_role_created' }
        end

        context 'with a missing param' do
          let(:error_message) { "Name can't be blank" }

          before do
            params.delete(:name)
          end

          it_behaves_like 'custom role create service returns error'
        end
      end
    end
  end
end
