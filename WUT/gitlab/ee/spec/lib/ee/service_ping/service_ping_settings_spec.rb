# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServicePing::ServicePingSettings do
  using RSpec::Parameterized::TableSyntax

  describe '#enabled_and_consented?' do
    where(
      :usage_ping_enabled,
      :customer_service_enabled,
      :requires_usage_stats_consent,
      :expected_enabled_and_consented
    ) do
      # Customer service enabled
      true  | true  | false | true
      false | true  | true  | false
      false | true  | false | true
      true  | true  | true  | false

      # Customer service disabled
      true  | false | false | true
      true  | false | true  | false
      false | false | false | false
      false | false | true  | false

      # When there is no license it should have same behaviour as ce
      true  | nil | false | true
      false | nil | false | false
      false | nil | true  | false
      true  | nil | true  | false
    end

    with_them do
      before do
        allow(User).to receive(:single_user)
          .and_return(instance_double(User, :user, requires_usage_stats_consent?: requires_usage_stats_consent))
        stub_config_setting(usage_ping_enabled: usage_ping_enabled)
        create_current_license(operational_metrics_enabled: customer_service_enabled)
      end

      it 'has the correct enabled_and_consented?' do
        expect(described_class.enabled_and_consented?).to eq(expected_enabled_and_consented)
      end
    end
  end

  describe '#license_operational_metric_enabled?' do
    where(:customer_service_enabled, :expected_license_operational_metric_enabled) do
      true  | true
      false | false
    end

    with_them do
      before do
        create_current_license(operational_metrics_enabled: customer_service_enabled)
      end

      it 'returns the correct value for license_operational_metric_enabled?' do
        expect(described_class.license_operational_metric_enabled?).to eq(expected_license_operational_metric_enabled)
      end
    end
  end

  describe '#enabled?' do
    where(:usage_ping_enabled, :customer_service_enabled, :expected_enabled) do
      true  | true  | true
      false | true  | true
      true  | false | true
      false | false | false
    end

    with_them do
      before do
        stub_config_setting(usage_ping_enabled: usage_ping_enabled)
        create_current_license(operational_metrics_enabled: customer_service_enabled)
      end

      it 'has the correct enabled?' do
        expect(described_class.enabled?).to eq(expected_enabled)
      end
    end
  end
end
