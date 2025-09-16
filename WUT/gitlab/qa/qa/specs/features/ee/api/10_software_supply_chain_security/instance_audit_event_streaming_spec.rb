# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :requires_admin,
    :skip_live_env, # We need to enable local requests to use a local mock streaming server
    product_group: :compliance,
    feature_flag: { name: :disable_audit_event_streaming }
  ) do
    describe 'Instance audit event streaming' do
      include_context 'with streamed events mock setup'

      let(:target_details) { entity_path }
      let(:event_types) { %w[remove_ssh_key group_created project_created user_created repository_git_operation] }

      let(:headers) do
        {
          'Test-Header1': 'instance event streaming',
          'Test-Header2': 'destination via api'
        }
      end

      before(:context) do
        Runtime::ApplicationSettings.enable_local_requests
      end

      before do
        stream_destination.add_headers(headers)
        stream_destination.add_filters(event_types)
        Runtime::Feature.disable(:disable_audit_event_streaming)

        mock_service.wait_for_streaming_to_start(event_type: 'remove_ssh_key', entity_type: 'User') do
          Resource::SSHKey.fabricate_via_api!.remove_via_api!
        end
      end

      context 'when a group is created' do
        let(:entity_path) { create(:group).full_path }

        include_examples 'streamed events', 'group_created', 'Group', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/415874'
      end

      context 'when a project is created', quarantine: {
        type: :investigating,
        issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/427266'
      } do
        # Create a group first so its audit event is streamed before we check for the create project event
        let!(:group) { create(:group) }
        let(:entity_path) { create(:project, group: group).full_path }

        include_examples 'streamed events', 'project_created', 'Project', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/415875'
      end

      context 'when a user is created', quarantine: {
        type: :investigating,
        issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/427266'
      } do
        let(:entity_path) { create(:user).username }

        include_examples 'streamed events', 'user_created', 'User', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/415876'
      end

      context 'when a repository is cloned via SSH' do
        # Create the project and key first so their audit events are streamed before we check for the clone event
        let!(:key) { Resource::SSHKey.fabricate_via_api! }
        let!(:project) { create(:project, :with_readme) }

        # Clone the repo via SSH and then use the project path and name to confirm the event details
        let(:target_details) { project.name }
        let(:entity_path) do
          Git::Repository.perform do |repository|
            repository.uri = project.repository_ssh_location.uri
            repository.use_ssh_key(key)
            repository.clone
          end

          project.full_path
        end

        include_examples 'streamed events', 'repository_git_operation', 'Project', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/415972'
      end
    end
  end
end
