# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AuditEventStreamingHeader'], feature_category: :audit_events do
  let(:fields) do
    %i[id key value active]
  end

  specify { expect(described_class.graphql_name).to eq('AuditEventStreamingHeader') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end
