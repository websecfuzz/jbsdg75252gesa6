# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoWorkflow::Client, feature_category: :duo_workflow do
  let_it_be(:user) { create(:user) }

  describe '.url' do
    it 'returns url to Duo Workflow Service fleet' do
      expect(described_class.url).to eq('duo-workflow-svc.runway.gitlab.net:443')
    end

    context 'when cloud connector url is staging' do
      before do
        allow(::CloudConnector::Config).to receive(:host).and_return('cloud.staging.gitlab.com')
      end

      it 'returns url to staging Duo Workflow Service fleet' do
        expect(described_class.url).to eq('duo-workflow-svc.staging.runway.gitlab.net:443')
      end
    end

    context 'when url is set in config' do
      let(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }

      before do
        allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
      end

      it 'returns configured url' do
        expect(described_class.url).to eq(duo_workflow_service_url)
      end
    end
  end

  describe '.headers' do
    it 'returns cloud connector headers' do
      expect(::CloudConnector).to receive(:ai_headers).with(user).and_return({ header_key: 'header_value' })

      expect(described_class.headers(user: user)).to eq({ header_key: 'header_value' })
    end
  end

  describe '.secure?' do
    it 'returns secure config' do
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return true
      expect(described_class.secure?).to eq(true)
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return false
      expect(described_class.secure?).to eq(false)
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return nil
      expect(described_class.secure?).to eq(false)
    end
  end

  describe '.cloud_connector_headers' do
    let(:token) { 'duo_workflow_token_123' }

    before do
      allow(::CloudConnector::Tokens).to receive(:get).and_return(token)
    end

    it 'returns headers with base URL, authorization, and authentication type' do
      expected_headers = {
        'authorization' => "Bearer #{token}",
        'x-gitlab-authentication-type' => 'oidc',
        'x-gitlab-base-url' => 'http://localhost',
        'x-gitlab-feature-enabled-by-namespace-ids' => '',
        'x-gitlab-global-user-id' => Gitlab::GlobalAnonymousId.user_id(user),
        'x-gitlab-host-name' => 'localhost',
        'x-gitlab-instance-id' => 'uuid-not-set',
        'x-gitlab-realm' => 'self-managed',
        'x-gitlab-version' => '18.2.0',
        'x-gitlab-enabled-instance-verbose-ai-logs' => 'true',
        'x-gitlab-enabled-feature-flags' => '',
        'x-gitlab-feature-enablement-type' => ''
      }

      expect(described_class.cloud_connector_headers(user: user)).to eq(expected_headers)
    end
  end

  describe '.cloud_connector_token' do
    let_it_be(:group) { create(:group, maintainers: user) }

    let(:token) { 'duo_workflow_token_456' }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      allow(::CloudConnector::Tokens).to receive(:get).and_return(token)
    end

    it 'gets token with correct parameters' do
      expect(::CloudConnector::Tokens).to receive(:get).with(
        unit_primitive: :duo_agent_platform,
        resource: user
      )

      expect(described_class.cloud_connector_token(user: user)).to eq(token)
    end
  end
end
