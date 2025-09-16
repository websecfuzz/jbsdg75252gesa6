# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).product_analytics_events_stored',
  feature_category: :product_analytics do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, owner_of: project) }

  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          productAnalyticsEventsStored(monthSelection: [
            { year: 2023, month: 1 },
            { year: 2022, month: 12 }
          ]) {
            year
            month
            count
          }
        }
      }
    )
  end

  subject do
    post_graphql(query, current_user: user)
  end

  context 'when project does not have product analytics enabled' do
    it "returns nil for each months usage" do
      subject

      graphql_data.dig('project', 'productAnalyticsEventsStored').each do |event|
        expect(event['count']).to be_nil
      end
    end
  end

  context 'when project does have product analytics enabled' do
    before do
      project.project_setting.update!(product_analytics_instrumentation_key: 'abc-123')
      allow_next_instance_of(ProductAnalytics::Settings) do |instance|
        allow(instance).to receive(:enabled?).and_return(true)
      end
    end

    context 'when user is not a project member' do
      let_it_be(:user) { create(:user) }

      it { is_expected.to be_nil }
    end

    it 'queries the ProjectUsageData interface with the correct parameters' do
      instance = Analytics::ProductAnalytics::ProjectUsageData.new(project_id: project.id)

      allow(Analytics::ProductAnalytics::ProjectUsageData).to receive(:new).and_return(instance)

      expect(instance).to receive(:events_stored_count).with(year: 2023, month: 1).once
      expect(instance).to receive(:events_stored_count).with(year: 2022, month: 12).once

      subject
    end
  end
end
