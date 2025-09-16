# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Access, :models, feature_category: :plan_provisioning do
  describe 'validations' do
    context 'when invalid catalog JSON is provided' do
      let(:cloud_connector_access) { build(:cloud_connector_access, catalog: []) }

      it 'is invalid' do
        expect(cloud_connector_access.valid?).to be false
        expect(cloud_connector_access.errors[:catalog]).to match_array ['must be a valid json schema']
      end
    end

    context 'when invalid data JSON is provided' do
      let(:cloud_connector_access) { build(:cloud_connector_access, data: []) }

      it 'is invalid' do
        expect(cloud_connector_access.valid?).to be false
        expect(cloud_connector_access.errors[:data]).to match_array ['must be a valid json schema']
      end
    end

    context 'when data is present and catalog is nil' do
      subject(:cloud_connector_access) { build(:cloud_connector_access, catalog: nil) }

      it { is_expected.to be_valid }
    end

    context 'when data is nil and catalog is present' do
      subject(:cloud_connector_access) { build(:cloud_connector_access, data: nil) }

      it { is_expected.to be_valid }
    end

    context 'when data is nil and catalog is nil' do
      subject(:cloud_connector_access) { build(:cloud_connector_access, data: nil, catalog: nil) }

      it { is_expected.not_to be_valid }

      it 'has relevant validation errors' do
        cloud_connector_access.valid?

        expect(cloud_connector_access.errors[:base]).to match_array ['Either valid data or catalog must be present']
      end
    end
  end

  describe 'scopes' do
    describe '.with_data' do
      let!(:access_with_data) { create(:cloud_connector_access) } # Uses factory defaults with data
      let!(:access_without_data) { create(:cloud_connector_access, data: nil) } # Only catalog

      it 'returns only records with data present' do
        result = described_class.with_data

        expect(result).to include(access_with_data)
        expect(result).not_to include(access_without_data)
      end
    end

    describe '.with_catalog' do
      let!(:access_with_catalog) { create(:cloud_connector_access) } # Uses factory defaults with catalog
      let!(:access_without_catalog) { create(:cloud_connector_access, catalog: nil) } # Only data

      it 'returns only records with catalog present' do
        result = described_class.with_catalog

        expect(result).to include(access_with_catalog)
        expect(result).not_to include(access_without_catalog)
      end
    end
  end
end
