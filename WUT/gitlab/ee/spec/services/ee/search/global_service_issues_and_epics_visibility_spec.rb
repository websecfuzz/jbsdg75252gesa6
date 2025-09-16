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

    context 'for issues' do
      let_it_be(:work_item) { create :work_item, project: project }

      let(:scope) { 'issues' }
      let(:search) { work_item.title }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access
      end

      with_them do
        before do
          Elastic::ProcessInitialBookkeepingService.track!(work_item)
          ensure_elasticsearch_index!
        end

        it_behaves_like 'search respects visibility'
      end
    end

    context 'for epics' do
      include_context 'for GroupPolicyTable context'

      let(:scope) { 'epics' }
      let(:search) { 'chosen epic title' }
      let_it_be(:epic) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'chosen epic title')
      end

      where(:group_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_epics_access
      end

      with_them do
        it 'respects visibility' do
          enable_admin_mode!(user_in_group) if admin_mode

          ::Elastic::ProcessBookkeepingService.track!(epic)
          group.update!(visibility_level: Gitlab::VisibilityLevel.level_value(group_level.to_s))
          ensure_elasticsearch_index!
          expect_search_results(user_in_group, scope, expected_count: expected_count) do |user|
            described_class.new(user, search: search).execute
          end
        end
      end
    end
  end
end
