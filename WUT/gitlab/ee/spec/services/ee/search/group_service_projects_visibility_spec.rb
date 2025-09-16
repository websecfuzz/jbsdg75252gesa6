# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'visibility', :elastic_delete_by_query do
    include_context 'ProjectPolicyTable context'

    let_it_be_with_refind(:group) { create(:group) }
    let_it_be_with_refind(:project) { create(:project, group: group) }
    let_it_be_with_refind(:project2) { create(:project) }

    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }

    let(:projects) { [project, project2] }
    let(:search_level) { group }

    context 'for projects' do
      where(:project_level, :membership, :expected_count) do
        permission_table_for_project_access
      end

      with_them do
        it 'respects visibility' do
          project.update!(visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s))

          Elastic::ProcessInitialBookkeepingService.track!(project)
          ensure_elasticsearch_index!

          expected_objects = expected_count == 1 ? [project] : []

          expect_search_results(
            user,
            'projects',
            expected_count: expected_count,
            expected_objects: expected_objects
          ) do |user|
            described_class.new(user, group, search: project.name).execute
          end
        end
      end
    end
  end
end
