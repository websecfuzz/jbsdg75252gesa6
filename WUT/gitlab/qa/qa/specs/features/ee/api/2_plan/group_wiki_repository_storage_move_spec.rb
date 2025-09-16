# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', product_group: :knowledge do
    describe 'Group Wiki repository storage', :requires_admin, :orchestrated, :repository_storage do
      let(:source_storage) { { type: :gitaly, name: 'default' } }
      let(:destination_storage) { { type: :gitaly, name: QA::Runtime::Env.additional_repository_storage } }
      let(:original_page_title) { 'Wiki page to move storage of' }
      let(:original_page_content) { 'Original wiki content' }

      let(:group) do
        create(:group,
          path: "group-to-move-storage-of-#{SecureRandom.hex(8)}",
          api_client: Runtime::API::Client.as_admin)
      end

      let(:wiki) do
        create(:group_wiki_page,
          title: original_page_title,
          content: original_page_content,
          group: group,
          api_client: Runtime::API::Client.as_admin)
      end

      praefect_manager = Service::PraefectManager.new

      before do
        praefect_manager.gitlab = 'gitlab'
      end

      it 'moves group Wiki repository from one Gitaly storage to another',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347644' do
        expect(wiki).to have_page_content(original_page_title, original_page_content)

        expect { group.change_repository_storage(destination_storage[:name]) }.not_to raise_error
        expect do
          praefect_manager.verify_storage_move(source_storage, destination_storage, repo_type: :group_wiki)
        end.not_to raise_error

        # verifies you can push commits to the moved Wiki
        Resource::Repository::WikiPush.fabricate! do |push|
          push.wiki = wiki
          push.repository_http_uri = "#{wiki.group.web_url.sub('/groups/', '/')}.wiki.git"
          push.file_name = 'new-page.md'
          push.file_content = 'new page content'
          push.commit_message = 'Adding a new Wiki page'
          push.new_branch = false
        end

        aggregate_failures do
          expect(wiki).to have_page_content(original_page_title, original_page_content)
          expect(wiki).to have_page_content('new page', 'new page content')
        end
      end
    end
  end
end
