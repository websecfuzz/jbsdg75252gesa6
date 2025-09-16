# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ProjectService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  describe 'visibility', :elastic_delete_by_query, :sidekiq_inline do
    include_context 'ProjectPolicyTable context'

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    context 'for notes' do
      let(:scope) { 'notes' }
      let(:search) { note.note }

      context 'on merge requests' do
        let_it_be_with_reload(:group) { create(:group) }
        let_it_be_with_reload(:project) { create(:project, group: group) }
        let(:projects) { [project] }
        let(:search_level) { project }

        let!(:note) { create :note_on_merge_request, project: project }

        let(:user_in_group) { create_user_from_membership(group, membership) }
        let(:user) { create_user_from_membership(project, membership) }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_reporter_feature_access
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end
    end
  end
end
