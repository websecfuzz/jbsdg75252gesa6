# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiModelSelectionFeatures'], feature_category: :"self-hosted_models" do
  it { expect(described_class.graphql_name).to eq('AiModelSelectionFeatures') }

  it 'exposes all the curated self-hosted features' do
    expected_result = ::Ai::ModelSelection::FeaturesConfigurable::FEATURES.each_key.map { |key| key.to_s.upcase }

    expect(described_class.values.keys).to include(*expected_result)
  end
end
