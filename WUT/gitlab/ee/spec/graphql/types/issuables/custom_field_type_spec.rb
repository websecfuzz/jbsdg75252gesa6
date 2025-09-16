# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomField'], feature_category: :team_planning do
  let(:fields) do
    %i[id name field_type active created_at created_by updated_at updated_by select_options work_item_types]
  end

  specify { expect(described_class.graphql_name).to eq('CustomField') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class).to require_graphql_authorizations(:read_custom_field) }
end
