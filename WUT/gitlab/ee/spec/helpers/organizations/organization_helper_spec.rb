# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::OrganizationHelper, feature_category: :organization do
  let_it_be(:organization_detail) { build_stubbed(:organization_detail, description_html: '<em>description</em>') }
  let_it_be(:organization) { organization_detail.organization }
  let_it_be(:activity_organization_path) { '/-/organizations/default/activity.json' }

  describe '#organization_activity_app_data' do
    let_it_be(:expected_event_types) do
      [
        {
          'title' => 'Comment',
          'value' => EventFilter::COMMENTS
        },
        {
          'title' => 'Design',
          'value' => EventFilter::DESIGNS
        },
        {
          'title' => 'Epic',
          'value' => EventFilter::EPIC
        },
        {
          'title' => 'Issue',
          'value' => EventFilter::ISSUE
        },
        {
          'title' => 'Merge',
          'value' => EventFilter::MERGED
        },
        {
          'title' => 'Repository',
          'value' => EventFilter::PUSH
        },
        {
          'title' => 'Membership',
          'value' => EventFilter::TEAM
        },
        {
          'title' => 'Wiki',
          'value' => EventFilter::WIKI
        }
      ]
    end

    before do
      allow(helper).to receive(:activity_organization_path)
        .with(organization, { format: :json })
        .and_return(activity_organization_path)
    end

    it 'returns expected data object' do
      expect(Gitlab::Json.parse(helper.organization_activity_app_data(organization))).to eq(
        {
          'organization_activity_path' => activity_organization_path,
          'organization_activity_event_types' => expected_event_types,
          'organization_activity_all_event' => EventFilter::ALL
        }
      )
    end
  end
end
