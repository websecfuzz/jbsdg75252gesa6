# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagers::InitializeService, feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(project, user) }

  subject(:result) { service.execute }

  describe '#execute' do
    let(:provision_worker_spy) { class_spy(SecretsManagement::ProvisionProjectSecretsManagerWorker) }

    before do
      stub_const('SecretsManagement::ProvisionProjectSecretsManagerWorker', provision_worker_spy)
    end

    it 'creates a secrets manager record for the project', :aggregate_failures do
      expect(result).to be_success

      secrets_manager = result.payload[:project_secrets_manager]
      expect(secrets_manager).to be_present
      expect(secrets_manager).to be_provisioning

      expect(provision_worker_spy).to have_received(:perform_async).with(user.id, secrets_manager.id)
    end

    context 'when there is an existing secrets manager record for the project' do
      it 'fails' do
        create(:project_secrets_manager, project: project)
        project.reload

        expect(result).to be_error
        expect(result.message).to eq('Secrets manager already initialized for the project.')
        expect(provision_worker_spy).not_to have_received(:perform_async)
      end
    end
  end
end
