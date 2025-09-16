# frozen_string_literal: true

require 'base64'

module QA
  describe 'Verify', :github, :requires_admin, only: { pipeline: %i[staging staging-canary] } do
    describe 'Pipeline for project mirrors Github', product_group: :pipeline_execution do
      include QA::Support::Data::Github

      let(:commit_message) { "Update #{github_data[:file_name]} - #{Time.now}" }
      let(:project_name) { 'github-project-with-pipeline' }
      let(:github_client) { Octokit::Client.new(access_token: github_data[:access_token]) }
      let(:admin_api_client) { Runtime::API::Client.as_admin }
      let(:github_data) do
        {
          access_token: Runtime::Env.github_access_token,
          file_name: 'text_file.txt',
          repo: "#{github_username}/test-project"
        }
      end

      let(:group) { create(:group, api_client: admin_api_client) }
      let(:user) { create(:user, :hard_delete, :with_personal_access_token) }
      let(:user_api_client) { user.api_client }

      let(:imported_project) do
        EE::Resource::ImportRepoWithCiCd.fabricate_via_browser_ui! do |project|
          project.import = true
          project.name = project_name
          project.group = group
          project.github_personal_access_token = github_data[:access_token]
          project.github_repository_path = github_data[:repo]
          project.api_client = user_api_client
          project.allow_partial_import = true
        end
      end

      before do
        # Create both tokens before logging in the first time so that we don't need to log out in the middle of the test
        admin_api_client.personal_access_token
        user_api_client.personal_access_token
        group.add_member(user, Resource::Members::AccessLevel::OWNER)

        Flow::Login.sign_in(as: user)
        imported_project # import project
      end

      it(
        'user commits to GitHub triggers CI pipeline',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347679',
        quarantine: {
          type: :investigating,
          issue: "https://gitlab.com/gitlab-org/gitlab/-/issues/417675"
        }
      ) do
        Page::Project::Menu.perform(&:go_to_pipelines)
        Page::Project::Pipeline::Index.perform do |index|
          expect(index).to have_no_pipeline, 'Expect to have NO pipeline before mirroring.'

          edit_github_file
          imported_project.trigger_project_mirror
          index.has_any_pipeline?

          expect(index).to have_content(commit_message), 'Expect new pipeline to have latest commit message from Github'
        end
      end

      private

      def edit_github_file
        Runtime::Logger.info "Making changes to Github file."

        github_file_contents = -> { github_client.contents(github_data[:repo], path: github_data[:file_name]) }

        file_contents = github_file_contents.call
        file_sha = file_contents.sha
        file_new_content = Faker::Lorem.sentence

        github_client.update_contents(
          github_data[:repo],
          github_data[:file_name],
          commit_message,
          file_sha,
          file_new_content
        )

        Support::Retrier.retry_until(max_attempts: 5, sleep_interval: 2) do
          contents = github_file_contents.call&.content
          Base64.decode64(contents) == file_new_content
        end
      end
    end
  end
end
