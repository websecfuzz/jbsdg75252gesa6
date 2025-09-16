# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::AgentVersionType, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogAgentVersion')
  end

  it 'implements the correct interface' do
    expect(described_class.interfaces).to include(Types::Ai::Catalog::VersionInterface)
  end

  it 'has the expected fields' do
    expected_fields = %w[
      system_prompt
      user_prompt
    ]

    expect(described_class.own_fields.size).to eq(expected_fields.size)
    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  it { expect(described_class).to require_graphql_authorizations(:read_ai_catalog_item) }
end
