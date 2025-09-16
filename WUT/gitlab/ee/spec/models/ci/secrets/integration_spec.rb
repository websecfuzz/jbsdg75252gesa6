# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Secrets::Integration, feature_category: :secrets_management do
  let_it_be_with_refind(:project) { create(:project) }
  let_it_be_with_refind(:pipeline) { create(:ci_pipeline, project: project) }
  let(:job) { create(:ci_build, pipeline: pipeline) }

  subject(:secrets_provider?) { job.secrets_provider?(nil) }

  describe '#secrets_provider?' do
    context 'when no secret CI variables are set' do
      it { is_expected.to eq(false) }
    end

    context 'when the VAULT_SERVER_URL is set' do
      before do
        project.variables.create!(key: 'VAULT_SERVER_URL', value: 'server_url')
      end

      it { is_expected.to eq(true) }
    end

    context 'when only one Azure key vault CI variable is set' do
      before do
        project.variables.create!(key: 'AZURE_KEY_VAULT_SERVER_URL', value: 'server_url')
      end

      it { is_expected.to eq(false) }
    end

    context 'when all Azure key vault CI variables are set' do
      before do
        project.variables.create!(key: 'AZURE_KEY_VAULT_SERVER_URL', value: 'server_url')
        project.variables.create!(key: 'AZURE_CLIENT_ID', value: 'client_ID')
        project.variables.create!(key: 'AZURE_TENANT_ID', value: 'tenant_id')
      end

      it { is_expected.to eq(true) }
    end

    context 'when only one GCP Secrets Manager CI variable is set' do
      before do
        project.variables.create!(key: 'GCP_PROJECT_NUMBER', value: '1234')
      end

      it { is_expected.to eq(false) }
    end

    context 'when all GCP Secrets Manager CI variables are set' do
      before do
        project.variables.create!(key: 'GCP_PROJECT_NUMBER', value: '1234')
        project.variables.create!(key: 'GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID', value: 'pool-id')
        project.variables.create!(key: 'GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID', value: 'provider-id')
      end

      it { is_expected.to eq(true) }
    end

    context 'with akeyless provider' do
      context 'when the AKEYLESS_ACCESS_ID is set' do
        before do
          project.variables.create!(key: 'AKEYLESS_ACCESS_ID', value: 'id')
        end

        it { is_expected.to eq(true) }
      end
    end
  end
end
