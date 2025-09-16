# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GlobalService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'visibility', :elastic_delete_by_query, :sidekiq_inline do
    include_context 'ProjectPolicyTable context'

    let_it_be_with_reload(:group) { create(:group, :wiki_enabled) }
    let_it_be_with_reload(:project) { create(:project, namespace: group) }
    let(:projects) { [project] }

    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }

    context 'for wikis' do
      let(:scope) { 'wiki_blobs' }
      let(:search) { 'term' }

      context 'for project wikis' do
        let_it_be_with_reload(:project) { create(:project, :wiki_repo) }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          before do
            project.wiki.create_page('test.md', "# #{search}")
            project.wiki.index_wiki_blobs
          end

          it_behaves_like 'search respects visibility', group_access: false
        end
      end

      context 'for group wikis' do
        let_it_be_with_reload(:group2) { create(:group, :wiki_enabled) }
        let_it_be(:group_wiki) { create(:group_wiki, container: group) }
        let_it_be(:group_wiki2) { create(:group_wiki, container: group2) }
        let(:groups) { [group, group2] }

        where(:group_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          before do
            [group_wiki, group_wiki2].each do |wiki|
              wiki.create_page('test.md', "# term")
              wiki.index_wiki_blobs
            end
            group2.add_member(user_in_group, membership) if %i[admin anonymous non_member].exclude?(membership)
          end

          it 'respects visibility' do
            enable_admin_mode!(user_in_group) if admin_mode

            groups.each do |g|
              g.update!(
                visibility_level: Gitlab::VisibilityLevel.level_value(group_level.to_s),
                wiki_access_level: feature_access_level.to_s
              )
            end

            ensure_elasticsearch_index!

            expect_search_results(user_in_group, scope, expected_count: expected_count * 2) do |_user|
              described_class.new(user_in_group, search: search).execute
            end
          end
        end
      end
    end
  end
end
