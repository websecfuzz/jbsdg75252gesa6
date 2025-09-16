# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Item, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:project).optional }

    it { is_expected.to have_many(:versions) }
    it { is_expected.to have_many(:consumers) }

    it { is_expected.to have_one(:latest_version) }

    describe '#latest_version' do
      it 'returns the latest version' do
        item = create(:ai_catalog_item, :with_version)
        latest_version = create(:ai_catalog_item_version, item: item, version: '1.0.1')

        expect(item.latest_version).to eq(latest_version)
      end
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:organization) }
    it { is_expected.to validate_presence_of(:item_type) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:name) }

    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1_024) }

    it { is_expected.to validate_inclusion_of(:public).in_array([true, false]) }

    it { expect(build(:ai_catalog_item)).to be_valid }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:item_type).with_values(agent: 1, flow: 2) }
  end

  describe 'scopes' do
    describe '.not_deleted' do
      let_it_be(:items) { create_list(:ai_catalog_item, 2) }
      let_it_be(:deleted_items) { create_list(:ai_catalog_item, 2, deleted_at: 1.day.ago) }

      it 'returns not deleted items' do
        expect(described_class.not_deleted).to match_array(items)
      end
    end

    describe '.with_item_type' do
      let_it_be(:agent_type_item) { create(:ai_catalog_item, item_type: :agent, public: true) }
      let_it_be(:flow_type_item) { create(:ai_catalog_item, item_type: :flow, public: true) }

      it 'returns items of the specified item type' do
        result = described_class.with_item_type(described_class::AGENT_TYPE)

        expect(described_class.count).to eq(2)
        expect(result).to contain_exactly(agent_type_item)
      end
    end
  end

  describe '#deleted?' do
    let(:item) { build_stubbed(:ai_catalog_item, deleted_at: deleted_at) }

    context 'when deleted_at is not nil' do
      let(:deleted_at) { 1.day.ago }

      it 'returns true' do
        expect(item).to be_deleted
      end
    end

    context 'when deleted_at is nil' do
      let(:deleted_at) { nil }

      it 'returns false' do
        expect(item).not_to be_deleted
      end
    end
  end
end
