# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::ItemInterface, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogItem')
  end

  it 'has the expected fields' do
    expected_fields = %w[
      created_at
      description
      id
      item_type
      name
      latest_version
      project
      public
      versions
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  describe ".resolve_type" do
    let_it_be(:user) { create(:user) }
    let_it_be(:item) { create(:ai_catalog_item, item_type: 'agent') }

    let(:context) { {} }

    subject(:resolve_type) { described_class.resolve_type(item, context) }

    it { is_expected.to eq(Types::Ai::Catalog::AgentType) }

    context 'when item_type is unknown' do
      before do
        allow(item).to receive(:item_type).and_return('unknown_type')
      end

      it 'raises an error' do
        expect { resolve_type }.to raise_exception(StandardError, 'Unknown catalog item type: unknown_type')
      end
    end
  end
end
