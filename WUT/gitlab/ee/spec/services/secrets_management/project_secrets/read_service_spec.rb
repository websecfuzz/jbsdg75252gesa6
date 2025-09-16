# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::ReadService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project) }

  let!(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:service) { described_class.new(project, user) }
  let(:name) { 'TEST_SECRET' }
  let(:description) { 'test description' }
  let(:branch) { 'main' }
  let(:environment) { 'prod' }
  let(:value) { 'secret-value' }

  describe '#execute' do
    context 'when secrets manager is active' do
      subject(:result) { service.execute(name) }

      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      context 'when the secret exists' do
        before do
          create_project_secret(
            user: user,
            project: project,
            name: name,
            description: description,
            branch: branch,
            environment: environment,
            value: value
          )
        end

        context 'with right permissions' do
          it 'returns success with the secret metadata' do
            expect(result).to be_success
            project_secret = result.payload[:project_secret]
            expect(project_secret).to be_a(SecretsManagement::ProjectSecret)
            expect(project_secret.name).to eq(name)
            expect(project_secret.description).to eq(description)
            expect(project_secret.branch).to eq(branch)
            expect(project_secret.environment).to eq(environment)
            expect(project_secret.metadata_version).to eq(1)
            expect(project_secret.project).to eq(project)
          end
        end
      end

      context 'when the secret does not exist' do
        it 'returns an error with not_found reason' do
          expect(result).to be_error
          expect(result.message).to eq('Project secret does not exist.')
          expect(result.reason).to eq(:not_found)
        end
      end

      context 'when the secret name does not conform' do
        let(:name) { '../../OTHER_SECRET' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq("Name can contain only letters, digits and '_'.")
        end
      end
    end

    context 'when user is a developer and no permissions' do
      let(:user) { create(:user, developer_of: project) }

      subject(:result) { service.execute(name) }

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)
        expect { result }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n")
      end
    end

    context 'when secrets manager is not active' do
      subject(:result) { service.execute(name) }

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active')
      end
    end
  end
end
