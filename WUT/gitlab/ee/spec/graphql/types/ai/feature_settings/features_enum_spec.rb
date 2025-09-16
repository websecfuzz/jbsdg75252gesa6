# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiFeatures'], feature_category: :"self-hosted_models" do
  it { expect(described_class.graphql_name).to eq('AiFeatures') }

  it 'exposes all the curated self-hosted features' do
    expected_result = ::Ai::FeatureSetting.allowed_features.each_key.map { |key| key.to_s.upcase }

    expect(described_class.values.keys).to include(*expected_result)
  end
end
