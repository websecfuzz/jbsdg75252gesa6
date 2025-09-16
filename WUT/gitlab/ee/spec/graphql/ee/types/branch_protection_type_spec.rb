# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['BranchProtection'], feature_category: :source_code_management do
  subject { described_class }

  let(:fields) do
    %i[
      allow_force_push
      code_owner_approval_required
      merge_access_levels
      push_access_levels
      unprotect_access_levels
      modification_blocked_by_policy
    ]
  end

  it { is_expected.to have_graphql_fields(fields).only }
end
