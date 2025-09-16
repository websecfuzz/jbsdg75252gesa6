# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::AdminRoles::DeleteService, feature_category: :permissions do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  subject(:service) { described_class.new(user) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe '#execute', :enable_admin_mode do
    let(:role) { create(:admin_role) }

    let(:enabled_permissions) { role.enabled_permissions(user).keys }

    subject(:result) { service.execute(role) }

    context 'with an authorized admin' do
      let_it_be(:user) { admin }

      it_behaves_like 'deleting a role' do
        let(:audit_event_message) { 'Admin role was deleted' }
        let(:audit_event_type) { 'admin_role_deleted' }
        let(:audit_event_abilities) { enabled_permissions.join(' ') }
      end
    end

    context 'with an unauthorized user' do
      it 'returns an error' do
        expect(result).to be_error
      end
    end
  end
end
