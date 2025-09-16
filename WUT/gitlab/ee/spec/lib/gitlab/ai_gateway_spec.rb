# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::AiGateway, feature_category: :system_access do
  let(:ai_setting) { Ai::Setting.instance }
  let(:url) { 'http://ai-gateway.example.com:5052' }
  let(:namespace_ids) { [1, 2, 3] }
  let(:enablement_type) { 'add_on' }
  let(:auth_response) do
    instance_double(Ai::UserAuthorizable::Response, namespace_ids: namespace_ids, enablement_type: enablement_type)
  end

  describe '.url' do
    context 'when ai_gateway_url setting is set' do
      it 'returns the setting value' do
        ai_setting.update!(ai_gateway_url: url)

        expect(described_class.url).to eq(url)
      end
    end

    context 'when ai_gateway_url setting is not set' do
      before do
        ai_setting.update!(ai_gateway_url: nil)
      end

      context 'when AI_GATEWAY_URL environment variable is set' do
        it 'returns the env var' do
          stub_env('AI_GATEWAY_URL', url)

          expect(described_class.url).to eq(url)
        end
      end

      context 'when AI_GATEWAY_URL is not set' do
        it 'returns the cloud connector url' do
          allow(::CloudConnector::Config).to receive(:base_url).and_return(url)

          expect(described_class.cloud_connector_url).to eq("#{url}/ai")
        end
      end
    end
  end

  describe '.cloud_connector_url' do
    context 'when AI_GATEWAY_URL environment variable is not set' do
      let(:url) { 'http:://example.com' }

      it 'returns the cloud connector url' do
        allow(::CloudConnector::Config).to receive(:base_url).and_return(url)

        expect(described_class.cloud_connector_url).to eq("#{url}/ai")
      end
    end
  end

  describe '.self_hosted_url' do
    context 'when the ai_gateway_url setting is set' do
      it 'returns the the setting value' do
        ai_setting.update!(ai_gateway_url: url)
        stub_env('AI_GATEWAY_URL', nil)

        expect(described_class.self_hosted_url).to eq(url)
      end
    end

    context 'when the ai_gateway_url setting is not set' do
      it 'returns the AI_GATEWAY_URL env var value' do
        ai_setting.update!(ai_gateway_url: nil)
        stub_env('AI_GATEWAY_URL', url)

        expect(described_class.self_hosted_url).to eq(url)
      end
    end
  end

  describe '.push_feature_flag', :request_store do
    before do
      allow(::Feature).to receive(:enabled?).and_return(true)
    end

    it 'push feature flag' do
      described_class.push_feature_flag("feature_a")
      described_class.push_feature_flag("feature_b")
      described_class.push_feature_flag("feature_c")

      expect(described_class.enabled_feature_flags).to match_array(%w[feature_a feature_b feature_c])
    end
  end

  describe '.enabled_feature_flags', :request_store do
    it 'returns empty' do
      expect(described_class.enabled_feature_flags).to eq([])
    end
  end

  describe '.headers', :request_store do
    let(:user) { build(:user, id: 1) }
    let(:token) { 'instance token' }
    let(:service_name) { :test }
    let(:service) { instance_double(CloudConnector::BaseAvailableServiceData, name: service_name) }
    let(:agent) { nil }
    let(:lsp_version) { nil }
    let(:standard_context) { instance_double(::Gitlab::Tracking::StandardContext) }
    let(:enabled_instance_verbose_ai_logs) { false }
    let(:is_team_member) { false }
    let(:cloud_connector_headers) do
      {
        'x-gitlab-host-name' => 'hostname',
        'x-gitlab-instance-id' => 'ABCDEF',
        'x-gitlab-global-User-Id' => '123ABC',
        'x-gitlab-realm' => 'self-managed',
        'x-gitlab-bersion' => '17.1.0',
        'x-gitlab-feature-enabled-by-namespace-ids' => namespace_ids.join(',')
      }
    end

    let(:expected_headers) do
      {
        'X-Gitlab-Authentication-Type' => 'oidc',
        'Authorization' => "Bearer #{token}",
        'x-gitlab-feature-enablement-type' => enablement_type,
        'x-gitlab-feature-enabled-by-namespace-ids' => namespace_ids.join(','),
        'Content-Type' => 'application/json',
        'X-Gitlab-Is-Team-Member' => is_team_member.to_s,
        'X-Request-ID' => an_instance_of(String),
        'X-Gitlab-Rails-Send-Start' => an_instance_of(String),
        'x-gitlab-enabled-feature-flags' => an_instance_of(String),
        'X-Gitlab-Client-Type' => 'ide',
        'X-Gitlab-Client-Version' => '1.0',
        'X-Gitlab-Client-Name' => 'gitlab-extension',
        'X-Gitlab-Interface' => 'vscode',
        'x-gitlab-enabled-instance-verbose-ai-logs' => 'false'
      }.merge(cloud_connector_headers)
    end

    subject(:headers) { described_class.headers(user: user, service: service, agent: agent, lsp_version: lsp_version) }

    before do
      allow_next_instance_of(::Ai::Setting) do |setting|
        allow(setting).to receive(:enabled_instance_verbose_ai_logs).and_return(enabled_instance_verbose_ai_logs)
      end

      allow(service).to receive(:access_token).with(user).and_return(token)
      allow(user).to receive(:allowed_to_use).with(service_name).and_return(auth_response)
      allow(::CloudConnector).to(
        receive(:ai_headers).with(user, namespace_ids: namespace_ids).and_return(cloud_connector_headers)
      )
      allow(::Gitlab::Tracking::StandardContext).to receive(:new).and_return(standard_context)
      allow(standard_context).to receive(:gitlab_team_member?).with(user&.id).and_return(is_team_member)

      described_class.current_context[:x_gitlab_client_type] = 'ide'
      described_class.current_context[:x_gitlab_client_version] = '1.0'
      described_class.current_context[:x_gitlab_client_name] = 'gitlab-extension'
      described_class.current_context[:x_gitlab_interface] = 'vscode'
    end

    it { is_expected.to match(expected_headers) }

    context 'when agent is set' do
      let(:agent) { 'user agent' }

      it { is_expected.to match(expected_headers.merge('User-Agent' => agent)) }
    end

    context 'when lsp_version is set' do
      let(:lsp_version) { '4.21.0' }

      it { is_expected.to match(expected_headers.merge('X-Gitlab-Language-Server-Version' => lsp_version)) }
    end

    context 'when Langsmith is enabled' do
      before do
        allow(Langsmith::RunHelpers).to receive(:enabled?).and_return(true)
        allow(Langsmith::RunHelpers).to receive(:to_headers).and_return({
          "langsmith-trace" => '20240808T090953171943Z18dfa1db-1dfc-4a48-aaf8-a139960955ce'
        })
      end

      it 'includes langsmith header' do
        expect(headers).to include(
          'langsmith-trace' => '20240808T090953171943Z18dfa1db-1dfc-4a48-aaf8-a139960955ce'
        )
      end
    end

    context 'when verbose logs are enabled for instance' do
      let(:enabled_instance_verbose_ai_logs) { true }

      it 'updates the header' do
        expect(headers).to include('x-gitlab-enabled-instance-verbose-ai-logs' => "true")
      end
    end

    context 'when feature flag is pushed' do
      before do
        allow(described_class).to receive(:enabled_feature_flags).and_return(%w[feature_a feature_b])
      end

      it 'includes feature flag header' do
        expect(headers).to include(
          'x-gitlab-enabled-feature-flags' => 'feature_a,feature_b'
        )
      end
    end

    context 'when there is no user' do
      let(:user) { nil }
      let(:namespace_ids) { [] }
      let(:enablement_type) { '' }

      it { is_expected.to match(expected_headers.merge('x-gitlab-feature-enabled-by-namespace-ids' => '')) }
    end

    context 'when user is a GitLab team member' do
      let(:is_team_member) { true }

      it { is_expected.to match(expected_headers) }
    end
  end

  describe '.public_headers' do
    let(:user) { build(:user, id: 1) }
    let(:service_name) { :test }
    let(:enabled_feature_flags) { %w[feature_a feature_b] }
    let(:ai_headers) { { 'x-gitlab-feature-enabled-by-namespace-ids' => '' } }

    subject(:public_headers) { described_class.public_headers(user: user, service_name: service_name) }

    before do
      allow_next_instance_of(::Ai::Setting) do |setting|
        allow(setting).to receive(:enabled_instance_verbose_ai_logs).and_return(false)
      end

      allow(user).to receive(:allowed_to_use)
        .with(service_name)
        .and_return(auth_response)

      allow(described_class).to receive(:enabled_feature_flags)
        .and_return(enabled_feature_flags)

      allow(::CloudConnector).to receive(:ai_headers)
        .with(user, namespace_ids: namespace_ids)
        .and_return(ai_headers)
    end

    it 'returns headers with enabled feature flags and AI headers' do
      expected_headers = {
        'x-gitlab-feature-enablement-type' => enablement_type,
        'x-gitlab-feature-enabled-by-namespace-ids' => '',
        'x-gitlab-enabled-feature-flags' => 'feature_a,feature_b',
        'x-gitlab-enabled-instance-verbose-ai-logs' => 'false'
      }

      expect(public_headers).to eq(expected_headers)
    end

    context 'when there are no enabled feature flags' do
      let(:enabled_feature_flags) { [] }

      it 'returns headers with empty feature flags string' do
        expected_headers = {
          'x-gitlab-feature-enablement-type' => enablement_type,
          'x-gitlab-feature-enabled-by-namespace-ids' => '',
          'x-gitlab-enabled-feature-flags' => '',
          'x-gitlab-enabled-instance-verbose-ai-logs' => 'false'
        }

        expect(public_headers).to eq(expected_headers)
      end
    end

    context 'when there are duplicate feature flags' do
      let(:enabled_feature_flags) { %w[feature_a feature_a feature_b] }

      it 'returns headers with unique feature flags' do
        expected_headers = {
          'x-gitlab-feature-enablement-type' => enablement_type,
          'x-gitlab-feature-enabled-by-namespace-ids' => '',
          'x-gitlab-enabled-feature-flags' => 'feature_a,feature_b',
          'x-gitlab-enabled-instance-verbose-ai-logs' => 'false'
        }

        expect(public_headers).to eq(expected_headers)
      end
    end
  end
end
