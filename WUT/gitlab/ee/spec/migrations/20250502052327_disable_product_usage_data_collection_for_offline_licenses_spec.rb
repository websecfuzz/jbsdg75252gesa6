# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe DisableProductUsageDataCollectionForOfflineLicenses, :migration, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  let(:application_settings) { table(:application_settings) }
  let(:service_ping_settings) { { 'some_other_setting' => true } }

  before do
    application_settings.create!(service_ping_settings: service_ping_settings, usage_ping_enabled: usage_ping_enabled)
    allow(Gitlab).to receive(:ee?).and_return(is_ee)

    if is_ee
      license = instance_double(License)
      stub_const('License', class_double(License, current: license))
      allow(License).to receive(:current).and_return(license)

      if license_present
        allow(license).to receive_messages(offline_cloud_license?: offline_cloud_license,
          customer_service_enabled?: customer_service_enabled)
      end
    end
  end

  where(:is_ee, :license_present, :offline_cloud_license, :customer_service_enabled, :usage_ping_enabled, :outcome) do
    [
      # Not EE
      [false, nil, nil, nil, true, 'does_not_update'],
      # EE, offline cloud license, all combinations, disable
      [true, true, true, true, true, 'disables'],
      [true, true, true, true, false, 'disables'],
      [true, true, true, false, true, 'disables'],
      [true, true, true, false, false, 'disables'],
      # EE, not offline cloud license
      [true, true, false, false, false, 'disables'], # usage ping and operational data is disabled

      [true, true, false, false, true, 'does_not_update'],
      [true, true, false, true, false, 'does_not_update'],
      [true, true, false, true, true, 'does_not_update']
    ]
  end

  with_them do
    it 'has the expected outcome' do
      case outcome
      when 'disables'
        migrate!

        expect(application_settings.first.service_ping_settings['gitlab_product_usage_data_enabled']).to be(false)
      when 'does_not_update'
        expect { migrate! }.not_to change { application_settings.first.service_ping_settings }
      end
    end
  end
end
