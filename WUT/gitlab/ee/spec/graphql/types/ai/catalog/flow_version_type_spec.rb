# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::FlowVersionType, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogFlowVersion')
  end

  it 'implements the correct interface' do
    expect(described_class.interfaces).to include(Types::Ai::Catalog::VersionInterface)
  end

  it 'has the expected fields' do
    expect(described_class.own_fields).to be_empty
  end

  it { expect(described_class).to require_graphql_authorizations(:read_ai_catalog_item) }
end
