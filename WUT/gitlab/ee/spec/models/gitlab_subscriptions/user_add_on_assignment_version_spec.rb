# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UserAddOnAssignmentVersion, feature_category: :seat_cost_management do
  it "includes PaperTrail::VersionConcern" do
    expect(described_class).to include(PaperTrail::VersionConcern)
  end

  it "includes EachBatch" do
    expect(described_class).to include(EachBatch)
  end
end
