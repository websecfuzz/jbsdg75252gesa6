# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::Dora::DoraMetricType, feature_category: :dora_metrics do
  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(
      :date, :deployment_frequency, :time_to_restore_service,
      :lead_time_for_changes, :change_failure_rate)
  end

  describe 'fields' do
    subject(:fields) { described_class.fields }

    it 'have proper types' do
      expect(fields['date']).to have_graphql_type(GraphQL::Types::String)
      expect(fields['deploymentFrequency']).to have_graphql_type(GraphQL::Types::Float)
      expect(fields['timeToRestoreService']).to have_graphql_type(GraphQL::Types::Float)
      expect(fields['leadTimeForChanges']).to have_graphql_type(GraphQL::Types::Float)
      expect(fields['changeFailureRate']).to have_graphql_type(GraphQL::Types::Float)
    end
  end
end
