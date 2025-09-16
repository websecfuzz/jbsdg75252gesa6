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

    let(:search_level) { group }
    let_it_be(:group) { create(:group, :public) }
    let_it_be_with_reload(:project) { create(:project, :repository, namespace: group) }
    let_it_be_with_reload(:project2) { create(:project, :repository) }
    let(:projects) { [project, project2] }
    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }

    where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
      permission_table_for_guest_feature_access_and_non_private_project_only
    end

    with_them do
      before do
        project.repository.index_commits_and_blobs
        project2.repository.index_commits_and_blobs
      end

      context 'for commits' do
        it_behaves_like 'search respects visibility' do
          let(:scope) { 'commits' }
          let(:search) { 'initial' }
        end
      end

      context 'for blobs' do
        it_behaves_like 'search respects visibility' do
          let(:scope) { 'blobs' }
          let(:search) { '.gitmodules' }
        end
      end
    end
  end
end
