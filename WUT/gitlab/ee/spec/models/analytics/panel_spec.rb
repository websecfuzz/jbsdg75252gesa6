# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::Panel, feature_category: :product_analytics do
  let_it_be(:user) { create(:user) }

  before do
    stub_licensed_features(product_analytics: true)
    stub_feature_flags(product_analytics_features: true)
    allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
      allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
        'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
      }))
    end
  end

  shared_examples 'loads the visualization' do
    before do
      project.project_setting.update!(product_analytics_instrumentation_key: "key")
    end

    it 'returns the correct object' do
      expect(subject.type).to eq('LineChart')
      expect(subject.options)
        .to eq({ 'xAxis' => { 'name' => 'Time', 'type' => 'time' }, 'yAxis' => { 'name' => 'Counts' } })
      expect(subject.data['type']).to eq('Cube')
    end
  end

  describe 'with file-based visualizations' do
    let_it_be(:project) { create(:project, :with_product_analytics_dashboard) }

    subject { project.product_analytics_dashboard('dashboard_example_1', user).panels.first.visualization }

    it_behaves_like 'loads the visualization'
  end

  describe 'with inline visualizations' do
    let_it_be(:project) { create(:project, :with_product_analytics_dashboard_with_inline_visualization) }

    subject { project.product_analytics_dashboard('dashboard_example_inline_vis', user).panels.first.visualization }

    it_behaves_like 'loads the visualization'
  end

  describe '.from_data' do
    let_it_be(:project) { create(:project, :with_product_analytics_dashboard) }

    it 'returns nil when yaml is missing' do # instead of raising a 500
      expect(described_class.from_data(nil, project, project)).to be_nil
    end
  end
end
