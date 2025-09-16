# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::SecretPermissionPolicy, feature_category: :secrets_management do
  subject(:policy) { described_class.new(user, secret_permission) }

  let_it_be(:user) { build(:user) }
  let_it_be(:project) { build_stubbed(:project) }
  let_it_be(:secret_permission) do
    SecretsManagement::SecretPermission.new(project: project, principal_type: 'Role',
      principal_id: 1,
      resource_type: 'Project',
      resource_id: project.id,
      permissions: %w[create read])
  end

  describe 'delegation' do
    let(:delegations) { policy.delegated_policies }

    it 'delegates to ProjectPolicy' do
      expect(delegations.size).to eq(1)

      delegations.each_value do |delegated_policy|
        expect(delegated_policy).to be_instance_of(::ProjectPolicy)
      end
    end
  end
end
