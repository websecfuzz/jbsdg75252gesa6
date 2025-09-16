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

    context 'for wikis' do
      let_it_be_with_reload(:project) { create(:project, :public, :wiki_repo) }
      let(:projects) { [project] }
      let(:search_level) { project }

      let(:user) { create_user_from_membership(project, membership) }

      let(:scope) { 'wiki_blobs' }
      let(:search) { 'term' }

      before do
        project.wiki.create_page('test.md', "# term")
        project.wiki.index_wiki_blobs
      end

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access
      end

      with_them do
        it_behaves_like 'search respects visibility', group_access: false
      end

      it 'adds correct routing field in the elasticsearch request' do
        project.wiki.create_page('test.md', "# term")
        described_class.new(nil, project, search: search).execute.objects(scope)
        assert_routing_field("n_#{project.root_ancestor.id}")
      end
    end
  end
end
