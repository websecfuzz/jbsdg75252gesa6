# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::DatabaseDataLoader, feature_category: :plan_provisioning do
  let(:unit_primitive_class) { Gitlab::CloudConnector::DataModel::UnitPrimitive }

  subject(:unit_primitive_loader) { described_class.new(unit_primitive_class) }

  describe '#load!' do
    context 'with valid catalog data' do
      before do
        create(:cloud_connector_access)
      end

      it 'returns objects with the correct set of attributes', :request_store do
        result = unit_primitive_loader.load!
        expect(result).not_to be_empty

        expect(result).to all(be_instance_of(Gitlab::CloudConnector::DataModel::UnitPrimitive))
        up = result.first

        expect(up.backend_services).to all(be_instance_of(Gitlab::CloudConnector::DataModel::BackendService))
        expect(up.license_types).to all(be_instance_of(Gitlab::CloudConnector::DataModel::LicenseType))
      end

      it 'parses cut_off_date fields as Time objects when present' do
        result = unit_primitive_loader.load!.select(&:cut_off_date)

        expect(result).not_to be_empty
        expect(result.map(&:cut_off_date)).to all(be_a(Time))
      end
    end

    context 'with an empty catalog record' do
      before do
        create(:cloud_connector_access, catalog: nil)
      end

      it 'returns an empty array' do
        expect(unit_primitive_loader.load!).to eq([])
      end

      it 'logs a warning' do
        expect(::Gitlab::AppLogger).to receive(:warn).with(
          message: 'Catalog is empty or not synced',
          class_name: described_class.name
        )

        unit_primitive_loader.load!
      end
    end

    context 'when the model key is missing in the catalog' do
      let(:data_model_class) { Gitlab::CloudConnector::DataModel::Base }
      let(:data_model_loader) { described_class.new(data_model_class) }

      before do
        create(:cloud_connector_access)
      end

      it 'returns an empty array' do
        expect(data_model_loader.load!).to eq([])
      end

      it 'logs a warning' do
        model_name = data_model_class.model_name.tableize
        expect(::Gitlab::AppLogger).to receive(:warn).with(
          message: "Catalog key '#{model_name}' is missing or empty",
          class_name: described_class.name
        )

        data_model_loader.load!
      end
    end

    context 'when SafeRequestStore caching is enabled', :request_store do
      before do
        create(:cloud_connector_access)
      end

      it 'loads the raw catalog only once even across different model loaders' do
        add_on_loader = described_class.new(Gitlab::CloudConnector::DataModel::AddOn)

        expect(CloudConnector::Access).to receive(:with_catalog).once.and_call_original

        unit_primitive_loader.load!
        add_on_loader.load!
      end

      it 'uses the correct cache key for different model loaders' do
        add_on_loader = described_class.new(Gitlab::CloudConnector::DataModel::AddOn)

        unit_primitives = unit_primitive_loader.load!
        add_ons = add_on_loader.load!

        allow(CloudConnector::Access).to receive(:with_catalog).and_return([])

        expect(unit_primitive_loader.load!).to eq(unit_primitives)
        expect(add_on_loader.load!).to eq(add_ons)
        expect(unit_primitive_loader.load!).not_to eq(add_on_loader.load!)
      end
    end
  end
end
