# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ScanResultPolicy'], feature_category: :security_policy_management do
  let(:fields) do
    %i[description edit_path enabled name updated_at yaml policy_scope csp]
  end

  include_context 'with approval policy specific fields'

  it { expect(described_class).to have_graphql_fields(fields + type_specific_fields) }
end
