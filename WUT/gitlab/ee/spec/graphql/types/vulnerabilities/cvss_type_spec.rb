# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CvssType'], feature_category: :vulnerability_management do
  let(:expected_fields) { %i[vector vendor version base_score overall_score severity] }

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
