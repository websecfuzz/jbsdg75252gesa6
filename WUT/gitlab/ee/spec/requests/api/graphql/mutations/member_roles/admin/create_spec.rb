# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'creating admin member role', :enable_admin_mode, feature_category: :permissions do
  include GraphqlHelpers

  let_it_be_with_reload(:current_user) { create(:admin) }

  let(:permissions) { MemberRole.all_customizable_admin_permissions.keys.map(&:to_s).map(&:upcase) }
  let(:enabled_permissions_result) { MemberRole.all_customizable_admin_permissions.keys }
  let(:input) do
    {
      permissions: permissions
    }
  end

  let(:fields) do
    <<~FIELDS
      errors
      memberRole {
        id
        enabledPermissions {
          nodes {
            value
          }
        }
      }
    FIELDS
  end

  let(:mutation) { graphql_mutation(:member_role_admin_create, input, fields) }

  subject(:create_member_role) { graphql_mutation_response(:member_role_admin_create) }

  context 'without the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'with the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it_behaves_like 'a mutation that creates a member role'
    end

    context 'when on self-managed' do
      it_behaves_like 'a mutation that creates a member role'

      context 'when custom_admin_roles FF is disabled' do
        before do
          stub_feature_flags(custom_admin_roles: false)
        end

        it_behaves_like 'a mutation that returns top-level errors',
          errors: ['`custom_admin_roles` feature flag is disabled.']
      end

      context 'when current user is not an admin' do
        before do
          current_user.update!(admin: false)
        end

        it_behaves_like 'a mutation that returns a top-level access error',
          errors: ["The resource that you are attempting to access does not exist or " \
            "you don't have permission to perform this action"]
      end
    end
  end
end
