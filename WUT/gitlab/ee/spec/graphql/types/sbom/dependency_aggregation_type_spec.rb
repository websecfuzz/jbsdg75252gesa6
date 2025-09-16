# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyAggregationType, feature_category: :dependency_management do
  it 'implements the DependencyInterface interface' do
    expect(described_class.interfaces).to include(Types::Sbom::DependencyInterface)
  end

  it { expect(described_class.graphql_name).to eq('DependencyAggregation') }
end
