# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group active tab', :js, feature_category: :groups_and_projects do
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before do
    group.add_maintainer(user)
    sign_in(user)
  end

  context 'on group Insights' do
    before do
      stub_licensed_features(insights: true)

      visit group_insights_path(group)
    end

    it_behaves_like 'page has active tab', _('Analyze')
    it_behaves_like 'page has active sub tab', _('Insights')
  end

  context 'on group Issue Analytics' do
    before do
      stub_licensed_features(issues_analytics: true)

      visit group_issues_analytics_path(group)
    end

    it_behaves_like 'page has active tab', _('Analyze')
    it_behaves_like 'page has active sub tab', _('Issue')
  end

  context 'on group Contribution Analytics' do
    before do
      visit group_contribution_analytics_path(group)
    end

    it_behaves_like 'page has active tab', _('Analyze')
    it_behaves_like 'page has active sub tab', _('Contribution')
  end

  context 'on group Productivity Analytics' do
    before do
      stub_licensed_features(productivity_analytics: true)

      visit group_analytics_productivity_analytics_path(group)
    end

    it_behaves_like 'page has active tab', _('Analyze')
    it_behaves_like 'page has active sub tab', _('Productivity')
  end
end
