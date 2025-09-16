# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAgentVersion'], feature_category: :mlops do
  it 'has specific fields' do
    expected_fields = %w[id model prompt created_at]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
