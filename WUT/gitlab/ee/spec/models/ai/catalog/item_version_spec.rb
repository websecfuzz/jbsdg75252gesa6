# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemVersion, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:item).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:definition) }
    it { is_expected.to validate_presence_of(:schema_version) }
    it { is_expected.to validate_presence_of(:version) }

    it { is_expected.to validate_length_of(:version).is_at_most(50) }

    it 'definition validates json_schema' do
      validator = described_class.validators_on(:definition).find { |v| v.is_a?(JsonSchemaValidator) }

      expect(validator.options[:filename]).to eq('ai_catalog_item_version_definition')
      expect(validator.instance_variable_get(:@size_limit)).to eq(64.kilobytes)
    end
  end

  describe 'callbacks' do
    describe 'before_create :populate_organization' do
      subject(:version) { create(:ai_catalog_item_version) }

      it 'assigns organization from item' do
        expect(version.organization).to eq(version.item.organization)
      end
    end
  end
end
