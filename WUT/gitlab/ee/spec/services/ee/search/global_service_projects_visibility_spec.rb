# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GlobalService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'visibility', :elastic_delete_by_query do
    include_context 'ProjectPolicyTable context'

    let_it_be_with_reload(:group) { create(:group, :wiki_enabled) }
    let_it_be_with_reload(:project) { create(:project, namespace: group) }
    let(:projects) { [project] }

    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }

    context 'for projects' do
      where(:project_level, :membership, :expected_count) do
        permission_table_for_project_access
      end

      with_them do
        it 'respects visibility' do
          project.update!(visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s))

          ensure_elasticsearch_index!

          expected_objects = expected_count == 1 ? [project] : []

          expect_search_results(
            user,
            'projects',
            expected_count: expected_count,
            expected_objects: expected_objects
          ) do |user|
            described_class.new(user, search: project.name).execute
          end
        end
      end
    end
  end
end
