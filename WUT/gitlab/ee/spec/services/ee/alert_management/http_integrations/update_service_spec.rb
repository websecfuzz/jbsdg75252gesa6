# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AlertManagement::HttpIntegrations::UpdateService, feature_category: :incident_management do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, maintainers: user) }
  let_it_be_with_reload(:integration) { create(:alert_management_http_integration, :inactive, project: project, name: 'Old Name') }
  let_it_be(:other_integration) { create(:alert_management_prometheus_integration, project: project) }

  let(:payload_example) do
    {
      'alert' => { 'name' => 'Test alert' },
      'started_at' => Time.current.strftime('%d %B %Y, %-l:%M%p (%Z)')
    }
  end

  let(:payload_attribute_mapping) do
    {
      'title' => { 'path' => %w[alert name], 'type' => 'string' },
      'start_time' => { 'path' => %w[started_at], 'type' => 'datetime' }
    }
  end

  let(:params) do
    {
      name: 'New name',
      type_identifier: :prometheus,
      payload_example: payload_example,
      payload_attribute_mapping: payload_attribute_mapping
    }
  end

  let(:service) { described_class.new(integration, user, params) }

  describe '#execute' do
    subject(:response) { service.execute }

    context 'with multiple HTTP integrations feature available' do
      before do
        stub_licensed_features(multiple_alert_http_integrations: true)
      end

      it 'successfully updates the integration with the custom mappings' do
        expect(response).to be_success

        integration = response.payload[:integration]
        expect(integration).to be_a(::AlertManagement::HttpIntegration)
        expect(integration.name).to eq('New name')
        expect(integration.payload_example).to eq(payload_example)
        expect(integration.payload_attribute_mapping).to eq(payload_attribute_mapping)
      end

      context 'when switching integration type' do
        it 'updates the integration type' do
          expect(response).to be_success

          integration = response.payload[:integration]
          expect(integration).to be_a(::AlertManagement::HttpIntegration)
          expect(integration.name).to eq('New name')
          expect(integration.type_identifier).to eq('prometheus')
          expect(integration.payload_example).to eq(payload_example)
          expect(integration.payload_attribute_mapping).to eq(payload_attribute_mapping)
        end
      end
    end

    context 'with multiple HTTP integrations feature unavailable' do
      it 'does not allow multiple integrations of the same type' do
        expect(response).to be_error
        expect(response.message).to eq('Multiple integrations of a single type are not supported for this project')
      end
    end
  end
end
