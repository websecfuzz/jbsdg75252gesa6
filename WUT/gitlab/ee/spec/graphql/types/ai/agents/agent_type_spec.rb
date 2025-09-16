# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAgent'], feature_category: :mlops do
  it 'has specific fields' do
    expected_fields = %w[id name created_at versions latest_version]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
