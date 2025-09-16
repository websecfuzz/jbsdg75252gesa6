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

    let_it_be(:group) { create(:group) }
    let(:search_level) { group }

    let(:scope) { 'wiki_blobs' }
    let(:search) { 'term' }

    context 'for wikis' do
      it 'adds correct routing field in the elasticsearch request' do
        described_class.new(nil, search_level, search: search).execute.objects(scope)
        assert_routing_field("n_#{search_level.root_ancestor.id}")
      end

      context 'for project wikis' do
        let_it_be_with_reload(:project) { create(:project, :wiki_repo, group: group) }
        let_it_be(:project_wiki) do
          create(:project_wiki, project: project).tap do |wiki|
            wiki.create_page('test.md', "# term")
          end
        end

        let(:projects) { [project] }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          let(:user) { create_user_from_membership(project, membership) }
          let(:user_in_group) { create_user_from_membership(group, membership) }

          before do
            project.wiki.index_wiki_blobs
          end

          it_behaves_like 'search respects visibility'
        end
      end

      context 'for group wikis' do
        let_it_be_with_reload(:group) { create(:group, :public, :wiki_enabled) }
        let_it_be_with_reload(:sub_group) { create(:group, :public, :wiki_enabled, parent: group) }
        let_it_be(:group_wiki) do
          create(:group_wiki, container: group).tap do |wiki|
            wiki.create_page('test.md', "# term")
          end
        end

        let_it_be(:sub_group_wiki) do
          create(:group_wiki, container: sub_group).tap do |wiki|
            wiki.create_page('test.md', "# term")
          end
        end

        where(:group_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          let(:user) { create_user_from_membership(group, membership) }

          before do
            sub_group_wiki.index_wiki_blobs
            group_wiki.index_wiki_blobs
          end

          it 'respects visibility' do
            enable_admin_mode!(user) if admin_mode
            sub_group.update!(
              visibility_level: Gitlab::VisibilityLevel.level_value(group_level.to_s),
              wiki_access_level: feature_access_level.to_s
            )
            group.update!(
              visibility_level: Gitlab::VisibilityLevel.level_value(group_level.to_s),
              wiki_access_level: feature_access_level.to_s
            )
            ensure_elasticsearch_index!

            expect_search_results(user, scope, expected_count: expected_count * 2) do |user|
              described_class.new(user, search_level, search: search).execute
            end
          end
        end
      end
    end
  end
end
