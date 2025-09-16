# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MavenRegistryUpstream'], feature_category: :virtual_registry do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) { %i[id position] }

  it { is_expected.to have_graphql_fields(fields) }
end
