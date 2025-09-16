# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyType, feature_category: :dependency_management do
  it 'implements the DependencyInterface interface' do
    expect(described_class.interfaces).to include(Types::Sbom::DependencyInterface)
  end

  it { expect(described_class).to require_graphql_authorizations(:read_dependency) }
  it { expect(described_class.graphql_name).to eq('Dependency') }
end
