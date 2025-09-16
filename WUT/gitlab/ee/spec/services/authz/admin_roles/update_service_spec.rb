# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::AdminRoles::UpdateService, feature_category: :permissions do
  let_it_be(:regular_user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let(:user) { regular_user }

  describe '#execute' do
    let_it_be(:existing_abilities) { Gitlab::CustomRoles::Definition.admin.keys.sample(3).index_with(true) }
    let(:updated_abilities) { existing_abilities.merge(existing_abilities.each_key.first => false) }
    let(:params) do
      {
        name: role_name,
        description: role_description,
        **updated_abilities
      }
    end

    let(:role_name) { 'new name' }
    let(:role_description) { 'new description' }

    subject(:result) { described_class.new(user, params).execute(role) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when admin role', :enable_admin_mode do
      let_it_be(:role) { create(:admin_role, **existing_abilities) }

      context 'with unauthorized user' do
        let(:user) { regular_user }

        it 'returns an error' do
          expect(result).to be_error
        end
      end

      context 'with authorized user' do
        let(:user) { admin }

        it_behaves_like 'custom role update' do
          let(:audit_event_message) { 'Admin role was updated' }
          let(:audit_event_type) { 'admin_role_updated' }
        end
      end
    end
  end
end
