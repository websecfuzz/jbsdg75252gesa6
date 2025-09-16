# frozen_string_literal: true

require 'spec_helper'
require_relative 'probes/test_probe'

RSpec.describe CloudConnector::StatusChecks::StatusService, feature_category: :duo_setting do
  let(:succeeded_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: true) }
  let(:failed_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: false) }
  let(:user) { build(:user) }

  subject(:service) { described_class.new(user: user, probes: probes) }

  describe '#initialize' do
    subject(:service) { described_class.new(user: user) }

    let(:default_probes) do
      [
        an_instance_of(CloudConnector::StatusChecks::Probes::LicenseProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::AccessProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::TokenProbe),
        an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe)
      ]
    end

    context 'when no probes are passed' do
      it 'creates default probes' do
        service_probes = service.probes

        expect(service_probes.count).to eq(6)
        expect(service_probes).to match(default_probes)
      end
    end

    context 'when self-hosted AI Gateway is set up' do
      before do
        allow(::Ai::Setting).to receive(:self_hosted?).and_return(true)
      end

      it 'uses a different set of probes' do
        service_probes = service.probes

        expect(service_probes.count).to eq(3)
        expect(service_probes[0]).to be_an_instance_of(
          CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe
        )
        expect(service_probes[1]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe)
        expect(service_probes[2]).to be_an_instance_of(
          CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe
        )
      end
    end

    context 'when Amazon Q is connected' do
      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
      end

      it 'adds Amazon Q probes to the list of probes' do
        amazon_q_probes = default_probes + [
          an_instance_of(CloudConnector::StatusChecks::Probes::AmazonQ::EndToEndProbe)
        ]

        expect(service.probes).to match(amazon_q_probes)
      end
    end

    context 'when CLOUD_CONNECTOR_SELF_SIGN_TOKENS is set' do
      let(:ai_gateway_url) { 'http://localhost:5002' }
      let(:local_host_probe) { instance_double(CloudConnector::StatusChecks::Probes::HostProbe) }

      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', 'true')

        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return(ai_gateway_url)
      end

      it 'uses a different set of probes' do
        expect(CloudConnector::StatusChecks::Probes::HostProbe).to(
          receive(:new).with(ai_gateway_url).and_return(local_host_probe)
        )

        service_probes = service.probes

        expect(service_probes.count).to eq(2)
        expect(service_probes[0]).to be(local_host_probe)
        expect(service_probes[1]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe)
      end
    end
  end

  describe '#execute' do
    context 'when all probes succeed' do
      let(:probes) { [succeeded_probe, succeeded_probe] }

      it 'executes all probes and returns successful status result' do
        expect(succeeded_probe).to receive(:execute).twice.and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be true
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to be_nil
      end
    end

    context 'when any probe fails' do
      let(:probes) { [succeeded_probe, failed_probe] }

      it 'executes all probes and returns unsuccessful status result' do
        expect(succeeded_probe).to receive(:execute).and_call_original
        expect(failed_probe).to receive(:execute).and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to eq('Some probes failed')
      end
    end

    context 'when all probes fail' do
      let(:probes) { [failed_probe, failed_probe] }

      it 'executes all probes and returns unsuccessful status result' do
        expect(failed_probe).to receive(:execute).twice.and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to eq('Some probes failed')
      end
    end

    context 'when a probe returns multiple results' do
      let(:probe_with_multiple_results) { succeeded_probe }
      let(:probes) { [failed_probe, probe_with_multiple_results] }

      it 'executes all probes and returns unsuccessful status result' do
        allow(probe_with_multiple_results).to receive(:execute).and_return([
          ::CloudConnector::StatusChecks::Probes::ProbeResult.new('test', true, 'success'),
          ::CloudConnector::StatusChecks::Probes::ProbeResult.new('test', false, 'failure')
        ])

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].map(&:message)).to contain_exactly('NOK', 'success', 'failure')
        expect(result.message).to eq('Some probes failed')
      end
    end
  end
end
