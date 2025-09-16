# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'visibility', :elastic_delete_by_query, :sidekiq_inline do
    include_context 'ProjectPolicyTable context'

    let_it_be_with_refind(:group) { create(:group) }
    let_it_be_with_refind(:project) { create(:project, group: group) }
    let_it_be_with_refind(:project2) { create(:project) }

    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }

    let(:projects) { [project, project2] }
    let(:search_level) { group }

    context 'for issues' do
      let_it_be(:work_item) { create(:work_item, project: project) }
      let_it_be(:work_item2) { create(:work_item, project: project2, title: work_item.title) }

      let(:scope) { 'issues' }
      let(:search) { work_item.title }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access
      end

      with_them do
        before do
          Elastic::ProcessInitialBookkeepingService.track!(work_item, work_item2)
          ensure_elasticsearch_index!
        end

        it_behaves_like 'search respects visibility'
      end
    end

    context 'for epics' do
      include_context 'for GroupPolicyTable context'

      let(:scope) { 'epics' }
      let(:search) { 'chosen epic title' }
      let(:search_level) { group } # search_level is used in the shared example
      let_it_be(:epic) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'chosen epic title')
      end

      where(:project_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_epics_access
      end

      with_them do
        before do
          # project associated with group must have visibility_level updated to allow
          # the shared example to update the group visibility_level setting. projects cannot
          # have higher visibility than the group to which they belong
          project.update!(
            visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s)
          )
          ::Elastic::ProcessBookkeepingService.track!(epic)
        end

        it_behaves_like 'search respects visibility', project_access: false
      end
    end
  end
end
