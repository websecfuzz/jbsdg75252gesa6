# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServicePing::BuildPayload, feature_category: :service_ping do
  describe '#execute' do
    subject(:service_ping_payload) { described_class.new.execute }

    include_context 'stubbed service ping metrics definitions'

    before do
      allow(User).to receive(:single_user)
        .and_return(instance_double(User, :user, requires_usage_stats_consent?: false))
    end

    context 'GitLab instance have a license' do
      # License.current.present? == true
      context 'Instance consented to submit optional product intelligence data' do
        before do
          # Gitlab::CurrentSettings.include_optional_metrics_in_service_ping? == true
          stub_application_setting(include_optional_metrics_in_service_ping: true)
        end

        context 'Instance subscribes to free TAM service' do
          before do
            # License.current.usage_ping? == true
            create_current_license(operational_metrics_enabled: true)
          end

          it_behaves_like 'complete service ping payload'
        end

        context 'Instance does NOT subscribe to free TAM service' do
          before do
            # License.current.usage_ping? == false
            create_current_license(operational_metrics_enabled: false)
          end

          it_behaves_like 'service ping payload with all expected metrics' do
            let(:expected_metrics) { standard_metrics + optional_metrics + operational_metrics }
          end
        end
      end

      context 'Instance does NOT consented to submit optional product intelligence data' do
        before do
          # Gitlab::CurrentSettings.include_optional_metrics_in_service_ping? == false
          stub_application_setting(include_optional_metrics_in_service_ping: false)
        end

        context 'Instance subscribes to free TAM service' do
          before do
            # License.current.usage_ping? == true
            create_current_license(operational_metrics_enabled: true)
          end

          it_behaves_like 'service ping payload with all expected metrics' do
            let(:expected_metrics) { standard_metrics + operational_metrics }
          end

          it_behaves_like 'service ping payload without restricted metrics' do
            let(:restricted_metrics) { optional_metrics }
          end
        end

        context 'Instance does NOT subscribe to free TAM service' do
          before do
            # License.current.usage_ping? == false
            create_current_license(operational_metrics_enabled: false)
          end

          it_behaves_like 'service ping payload with all expected metrics' do
            let(:expected_metrics) { standard_metrics + operational_metrics }
          end

          it_behaves_like 'service ping payload without restricted metrics' do
            let(:restricted_metrics) { optional_metrics }
          end
        end
      end
    end
  end
end
