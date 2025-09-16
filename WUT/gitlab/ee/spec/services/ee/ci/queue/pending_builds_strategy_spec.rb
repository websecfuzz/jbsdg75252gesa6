# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Queue::PendingBuildsStrategy, :freeze_time, feature_category: :continuous_integration do
  let(:runner) { create(:ci_runner, :instance, :online) }
  let(:relation) { Ci::PendingBuild.all }
  let(:pending_build) { create(:ci_pending_build) }

  subject(:service) { described_class.new(runner) }

  describe '.enforce_minutes_limit' do
    it 'restricts to the with_ci_minutes_available scope' do
      expect(relation).to receive(:with_ci_minutes_available).and_return([pending_build])
      expect(service.enforce_minutes_limit(relation)).to include(pending_build)
    end
  end

  describe '.enforce_allowed_plan_ids' do
    let(:allowed_plan_ids) { [1, 2] }

    it 'restricts to the with_allowed_plan_ids scope' do
      expect(relation).to receive(:with_allowed_plan_ids).with(allowed_plan_ids).and_return([pending_build])
      expect(service.enforce_allowed_plan_ids(relation, allowed_plan_ids)).to include(pending_build)
    end
  end
end
