# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagers::UserHelper, feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }
  let(:secrets_manager) { build(:project_secrets_manager, project: project) }

  describe '#user_auth_mount' do
    let(:namespace_path) { "#{project.namespace.type.downcase}_#{project.namespace.id}" }

    it 'returns the correct mount path' do
      expect(secrets_manager.user_auth_mount).to eq("#{namespace_path}/user_jwt")
    end
  end

  describe '#user_auth_role' do
    it 'returns the correct auth role' do
      expect(secrets_manager.user_auth_role).to eq("project_#{project.id}")
    end
  end

  describe '#user_auth_policies' do
    it 'returns the user_auth_policies' do
      policies = secrets_manager.user_auth_policies

      expect(policies).to be_an(Array)
      expect(policies.size).to eq(described_class::MAX_GROUPS + 3)
      expect(policies.first).to eq(secrets_manager.user_policy_template)
      expect(policies.second).to eq(secrets_manager.member_role_policy_template)
      expect(policies.last).to eq(secrets_manager.role_policy_template)
    end
  end
end
