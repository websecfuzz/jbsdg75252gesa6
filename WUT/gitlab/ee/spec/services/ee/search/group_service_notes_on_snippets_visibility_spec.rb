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
    let_it_be_with_refind(:project) { create(:project, :repository, group: group) }
    let_it_be_with_refind(:project2) { create(:project, :repository) }

    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }

    let(:projects) { [project, project2] }
    let(:search_level) { group }

    context 'for notes' do
      let(:scope) { 'notes' }
      let(:search) { note.note }

      context 'on snippets' do
        let_it_be(:note) { create :note_on_project_snippet, project: project }
        let_it_be(:note2) { create :note_on_project_snippet, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          before do
            Elastic::ProcessInitialBookkeepingService.track!(note, note2)
            ensure_elasticsearch_index!
          end

          it_behaves_like 'search respects visibility'
        end
      end
    end
  end
end
