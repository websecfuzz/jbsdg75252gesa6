# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CycleAnalytics::StageSummary, feature_category: :devops_reports do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, :admin, maintainer_of: project) }

  let(:options) { { from: 1.day.ago } }
  let(:args) { { options: options, current_user: user } }

  let(:stage_summary) { described_class.new(project, **args).data }

  it_behaves_like 'deployment metrics examples'

  it 'does not use the DORA API' do
    expect(Dora::AggregateMetricsService).not_to receive(:new).and_call_original

    stage_summary
  end

  context 'when cycle_analytics_for_projects feature is available' do
    before do
      stub_licensed_features(cycle_analytics_for_projects: true)
    end

    it_behaves_like 'deployment metrics examples'

    it 'uses the DORA API' do
      expect(Dora::AggregateMetricsService).to receive(:new).and_call_original

      stage_summary
    end
  end
end
