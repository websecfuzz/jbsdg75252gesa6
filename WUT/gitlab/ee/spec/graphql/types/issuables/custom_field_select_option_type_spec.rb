# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomFieldSelectOption'], feature_category: :team_planning do
  let(:fields) do
    %i[id value]
  end

  specify { expect(described_class.graphql_name).to eq('CustomFieldSelectOption') }

  specify { expect(described_class).to have_graphql_fields(fields) }
end
