# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/analytics/dashboards/index',
  :aggregate_failures, feature_category: :value_stream_management do
  let_it_be(:group) { build(:group) }
  let_it_be(:another_group) { build(:group) }
  let_it_be(:subgroup) { build(:group, parent: group) }
  let_it_be(:project) { build(:project, :public, group: group) }
  let_it_be(:user) do
    build(:user).tap do |user|
      group.add_reporter(user)
      another_group.add_reporter(user)
    end
  end

  before do
    stub_licensed_features(group_level_analytics_dashboard: true)

    assign(:group, group)
  end

  it 'renders as expected' do
    render

    expect(rendered).to have_selector('#js-analytics-dashboards-list-app')
    expect(rendered).to have_css("[data-namespace-full-path='#{group.full_path}']")
  end
end
