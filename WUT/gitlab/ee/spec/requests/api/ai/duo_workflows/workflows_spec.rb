# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::Workflows, :with_current_organization, feature_category: :duo_workflow do
  include HttpBasicAuthHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, user: user, project: project) }
  let_it_be(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }
  let_it_be(:ai_workflows_oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }
  let(:agent_privileges) { [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES] }
  let(:pre_approved_agent_privileges) { [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES] }
  let(:workflow_definition) { 'software_development' }
  let(:allow_agent_to_request_user) { false }

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
    allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
    # rubocop:enable RSpec/AnyInstanceOf
  end

  describe 'POST /ai/duo_workflows/workflows' do
    let(:path) { "/ai/duo_workflows/workflows" }
    let(:params) do
      {
        project_id: project.id,
        agent_privileges: agent_privileges,
        pre_approved_agent_privileges: pre_approved_agent_privileges,
        workflow_definition: workflow_definition,
        allow_agent_to_request_user: allow_agent_to_request_user,
        image: "example.com/example-image:latest",
        environment: "web"
      }
    end

    context 'when workflow is chat' do
      let(:workflow_definition) { 'chat' }

      before do
        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(user: user, service_name: :duo_workflow)
          .and_return({ 'x-gitlab-enabled-feature-flags' => 'test-feature' })
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, project).and_return(true)
      end

      it 'creates the Ai::DuoWorkflows::Workflow' do
        expect do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

        created_workflow = Ai::DuoWorkflows::Workflow.last

        expect(created_workflow.workflow_definition).to eq(workflow_definition)
      end
    end

    context 'when success' do
      before do
        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(user: user, service_name: :duo_workflow)
          .and_return({ 'x-gitlab-enabled-feature-flags' => 'test-feature' })
      end

      it 'creates the Ai::DuoWorkflows::Workflow' do
        expect do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

        expect(json_response['id']).to eq(Ai::DuoWorkflows::Workflow.last.id)
        expect(json_response['environment']).to eq("web")
        expect(response.headers['X-Gitlab-Enabled-Feature-Flags']).to include('test-feature')

        created_workflow = Ai::DuoWorkflows::Workflow.last

        expect(created_workflow.agent_privileges).to eq(agent_privileges)
        expect(created_workflow.pre_approved_agent_privileges).to eq(pre_approved_agent_privileges)
        expect(created_workflow.workflow_definition).to eq(workflow_definition)
        expect(created_workflow.allow_agent_to_request_user).to eq(allow_agent_to_request_user)
        expect(created_workflow.image).to eq("example.com/example-image:latest")
        expect(created_workflow.environment).to eq("web")
      end

      context 'when agent_privileges is not provided' do
        let(:params) { { project_id: project.id } }

        it 'creates a workflow with the default agent_privileges' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)

          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.agent_privileges).to match_array(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES
          )
        end
      end

      context 'when pre_approved_agent_privileges is not provided' do
        let(:params) do
          {
            project_id: project.id,
            agent_privileges: ::Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES
          }
        end

        it 'creates a workflow with the default pre_approved_agent_privileges' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)

          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.pre_approved_agent_privileges).to match_array(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES
          )
        end
      end

      context 'when pre_approved_agent_privileges has invalid privilege' do
        let(:params) do
          {
            project_id: project.id,
            agent_privileges: [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
            pre_approved_agent_privileges: [999]
          }
        end

        it 'returns bad request' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when pre_approved_agent_privileges contains privilege not in agent_privileges' do
        let(:params) do
          {
            project_id: project.id,
            agent_privileges: [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
            pre_approved_agent_privileges: [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB]
          }
        end

        it 'returns bad request' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when allow_agent_to_request_user is not provided' do
        it 'creates a workflow with the default of true' do
          post api(path, user), params: params.except(:allow_agent_to_request_user)
          expect(response).to have_gitlab_http_status(:created)

          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.allow_agent_to_request_user).to eq(true)
        end
      end

      context 'when workflow definition is not provided' do
        let(:params) { { project_id: project.id } }

        it 'creates a workflow with the default workflow_definition' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)

          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.workflow_definition).to eq('software_development')
        end
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is forbidden' do
          post api(path, oauth_access_token: ai_workflows_oauth_token), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with project path params' do
        let(:params) { { project_id: project.full_path } }

        it 'is successful' do
          expect do
            post api(path, user), params: params
            expect(response).to have_gitlab_http_status(:created)
          end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end

    context 'when failure' do
      shared_examples 'workflow access is forbidden' do
        it 'workflow access is forbidden' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with a project where the user is not a developer' do
        let(:user) { create(:user, guest_of: project) }

        it_behaves_like 'workflow access is forbidden'
      end

      context 'when the duo_workflows feature flag is disabled for the user' do
        before do
          stub_feature_flags(duo_workflow: false)
        end

        it_behaves_like 'workflow access is forbidden'
      end

      context 'when duo_features_enabled settings is turned off' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
          project.reload
        end

        it_behaves_like 'workflow access is forbidden'
      end
    end

    context 'when start_workflow is true' do
      shared_examples 'starts duo workflow execution in CI' do
        it 'creates a pipeline to run the workflow' do
          expect_next_instance_of(Ci::CreatePipelineService) do |pipeline_service|
            expect(pipeline_service).to receive(:execute).and_call_original
          end

          post api(path, user), params: params
          expect(json_response['id']).to eq(Ai::DuoWorkflows::Workflow.last.id)
          expect(json_response['workload']['id']).to eq(Ci::Workloads::Workload.last.id)
          expect(::Ci::Pipeline.last.project_id).to eq(project.id)
        end
      end

      let(:params) do
        {
          project_id: project.id,
          start_workflow: true,
          goal: 'Print hello world'
        }
      end

      before do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:generate_token).and_return({ status: "success", token: "an-encrypted-token" })
        end
        allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
          allow(service).to receive(:execute).and_return({ status: :success,
oauth_access_token: instance_double('Doorkeeper::AccessToken', plaintext_token: 'oauth_token') })
        end
      end

      it_behaves_like 'starts duo workflow execution in CI'

      context 'when Feature flag is disabled' do
        before do
          stub_feature_flags(duo_workflow_in_ci: false)
        end

        it 'does not start a CI pipeline' do
          post api(path, user), params: params

          expect(json_response.dig('workload', 'id')).to eq(nil)
          expect(json_response.dig('workload', 'message')).to eq('Can not execute workflow in CI')
        end
      end

      context 'when ci pipeline could not be created' do
        let(:pipeline) do
          instance_double('Ci::Pipeline', created_successfully?: false, full_error_messages: 'full error messages')
        end

        let(:service_response) { ServiceResponse.error(message: 'Error in creating pipeline', payload: pipeline) }

        before do
          allow_next_instance_of(::Ci::CreatePipelineService) do |instance|
            allow(instance).to receive(:execute).and_return(service_response)
          end
        end

        it 'does not start a pipeline to execute workflow' do
          post api(path, user), params: params
          expect(json_response['id']).to eq(Ai::DuoWorkflows::Workflow.last.id)
          expect(json_response.dig('workload', 'id')).to eq(nil)
          expect(json_response.dig('workload', 'message')).to eq('Error in creating workload: full error messages')
        end
      end

      context 'when use_service_account is set to true' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'Print hello world',
            use_service_account: true
          }
        end

        let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }

        before do
          allow_next_instance_of(::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService) do |service|
            allow(service).to receive(:execute).and_return({
              status: :success,
              oauth_access_token: instance_double('Doorkeeper::AccessToken', plaintext_token: 'oauth_token')
            })
          end
          ::Ai::Setting.instance.update!(
            duo_workflow_service_account_user_id: service_account.id
          )
          project.update!(allow_composite_identities_to_run_pipelines: true)
        end

        it_behaves_like 'starts duo workflow execution in CI'
      end

      context 'when source_branch is provided' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'Print hello world',
            source_branch: 'feature-branch'
          }
        end

        it 'passes source_branch to StartWorkflowService' do
          expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).with(
            workflow: anything,
            params: hash_including(source_branch: 'feature-branch')
          ).and_call_original

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when environment argument has invalid value' do
        let(:params) { super().merge(environment: 'invalid') }

        it 'returns bad request' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq({ "error" => "environment does not have a valid value" })
        end
      end
    end
  end

  describe 'POST /ai/duo_workflows/direct_access' do
    let(:path) { '/ai/duo_workflows/direct_access' }

    let(:post_without_params) { post api(path, user) }
    let(:post_with_definition) { post api(path, user), params: { workflow_definition: workflow_definition } }

    before do
      allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
      stub_config(duo_workflow: {
        executor_binary_url: 'https://example.com/executor',
        executor_binary_urls: {
          'linux/arm' => 'https://example.com/linux-arm-executor.tar.gz',
          'darwin/arm64' => 'https://example.com/darwin-arm64-executor.tar.gz'
        },
        service_url: duo_workflow_service_url,
        executor_version: 'v1.2.3',
        secure: true
      })
    end

    context 'when the duo_workflows is disabled for the user' do
      before do
        stub_feature_flags(duo_workflow: false)
      end

      context 'when workflow_definition is software_developer' do
        let(:workflow_definition) { 'software_developer' }

        it 'returns not found' do
          post_with_definition

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when workflow_definition is chat' do
        let(:workflow_definition) { 'chat' }

        it 'process request further' do
          post_with_definition

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when workflow_definition is omitted' do
        it 'process request further' do
          post_without_params

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when agentic_chat feature flag is disabled for the user' do
      before do
        stub_feature_flags(duo_agentic_chat: false)
      end

      context 'when workflow_definition is chat' do
        let(:workflow_definition) { 'chat' }

        it 'returns not found' do
          post_with_definition

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when workflow_definition is software_developer' do
        let(:workflow_definition) { 'software_developer' }

        it 'process request further' do
          post_with_definition

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when the duo_workflows and agentic_chat feature flag is disabled for the user' do
      before do
        stub_feature_flags(duo_workflow: false)
        stub_feature_flags(duo_agentic_chat: false)
      end

      it 'returns not found' do
        post_without_params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when rate limited' do
      it 'returns api error' do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)

        post_without_params

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'when CreateOauthAccessTokenService returns error' do
      it 'returns api error' do
        expect_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
          expect(service).to receive(:execute).and_return({ status: :error, http_status: :forbidden,
message: 'Duo workflow is not enabled for user' })
        end

        post_without_params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when DuoWorkflowService returns error' do
      it 'returns api error' do
        expect_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          expect(client).to receive(:generate_token).and_return({ status: :error,
message: "could not generate token" })
        end

        post_without_params

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when success' do
      let(:gitlab_rails_token_expires_at) { 2.hours.from_now.to_i }
      let(:duo_workflow_service_token_expires_at) { 1.hour.from_now.to_i }

      before do
        allow(::CloudConnector).to receive(:ai_headers).with(user).and_return({ header_key: 'header_value' })
        allow_next_instance_of(::Gitlab::Tracking::StandardContext) do |context|
          allow(context).to receive(:gitlab_team_member?).and_return(false)
          allow(context).to receive(:gitlab_team_member?).with(user.id).and_return(true)
        end
        allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
          allow(service).to receive(:execute).and_return({ status: :success,
oauth_access_token: instance_double('Doorkeeper::AccessToken', plaintext_token: 'oauth_token',
  expires_at: gitlab_rails_token_expires_at) })
        end
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:generate_token).and_return({ status: :success, token: 'duo_workflow_token',
expires_at: duo_workflow_service_token_expires_at })
        end
      end

      it 'returns access payload' do
        post_without_params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['gitlab_rails']['base_url']).to eq(Gitlab.config.gitlab.url)
        expect(json_response['gitlab_rails']['token']).to eq('oauth_token')
        expect(json_response['gitlab_rails']['token_expires_at']).to eq(gitlab_rails_token_expires_at)
        expect(json_response['duo_workflow_service']['base_url']).to eq("duo-workflow-service.example.com:50052")
        expect(json_response['duo_workflow_service']['token']).to eq('duo_workflow_token')
        expect(json_response['duo_workflow_service']['headers']['header_key']).to eq("header_value")
        expect(json_response['duo_workflow_service']['secure']).to eq(Gitlab::DuoWorkflow::Client.secure?)
        expect(json_response['duo_workflow_service']['token_expires_at']).to eq(duo_workflow_service_token_expires_at)
        expect(json_response['duo_workflow_executor']['executor_binary_url']).to eq('https://example.com/executor')
        expect(json_response['duo_workflow_executor']['version']).to eq('v1.2.3')
        expect(json_response['workflow_metadata']['extended_logging']).to eq(true)
        expect(json_response['workflow_metadata']['is_team_member']).to eq(true)
        expect(json_response['duo_workflow_executor']['executor_binary_urls']).to eq({
          'linux/arm' => 'https://example.com/linux-arm-executor.tar.gz',
          'darwin/arm64' => 'https://example.com/darwin-arm64-executor.tar.gz'
        })
      end

      context 'when duo_workflow_extended_logging is disabled' do
        before do
          stub_feature_flags(duo_workflow_extended_logging: false)
        end

        it 'returns workflow_metadata.extended_logging: false' do
          post_without_params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['workflow_metadata']['extended_logging']).to eq(false)
        end
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is forbidden' do
          post api(path, oauth_access_token: ai_workflows_oauth_token)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe 'GET /ai/duo_workflows/ws' do
    let(:path) { '/ai/duo_workflows/ws' }

    include_context 'workhorse headers'

    before do
      allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
        allow(service).to receive(:execute).and_return({
          status: :success,
          oauth_access_token: instance_double('Doorkeeper::AccessToken', plaintext_token: 'oauth_token')
        })
      end

      allow(Gitlab::DuoWorkflow::Client).to receive_messages(
        url: 'duo-workflow-service.example.com:50052',
        secure?: true
      )

      allow(::CloudConnector::Tokens).to receive(:get).and_return('token')
    end

    context 'when user is authenticated' do
      it 'returns the websocket configuration with proper headers' do
        get api(path, user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.media_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)

        expect(json_response['DuoWorkflow']['Headers']).to include(
          'x-gitlab-base-url' => Gitlab.config.gitlab.url,
          'x-gitlab-oauth-token' => 'oauth_token',
          'authorization' => 'Bearer token',
          'x-gitlab-authentication-type' => 'oidc',
          'x-gitlab-enabled-feature-flags' => anything,
          'x-gitlab-instance-id' => anything,
          'x-gitlab-version' => Gitlab.version_info.to_s
        )

        expect(json_response['DuoWorkflow']['ServiceURI']).to eq('duo-workflow-service.example.com:50052')
        expect(json_response['DuoWorkflow']['Secure']).to eq(true)
      end

      context 'when duo_workflow_workhorse feature flag is disabled' do
        before do
          stub_feature_flags(duo_workflow_workhorse: false)
        end

        it 'is forbidden' do
          get api(path, user), headers: workhorse_headers

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when the duo_workflows and agentic_chat feature flag is disabled for the user' do
        before do
          stub_feature_flags(duo_workflow: false)
          stub_feature_flags(duo_agentic_chat: false)
        end

        it 'returns not found' do
          get api(path, user), headers: workhorse_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when CreateOauthAccessTokenService returns an error' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
          allow(service).to receive(:execute).and_return({
            status: :error,
            http_status: :unauthorized,
            message: 'Failed to generate OAuth token'
          })
        end
      end

      it 'returns an error response' do
        get api(path, user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(json_response['message']).to eq('Failed to generate OAuth token')
      end
    end

    context 'when Workhorse header is missing' do
      it 'returns an error response' do
        get api(path, user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it 'is forbidden' do
        get api(path, oauth_access_token: ai_workflows_oauth_token), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/agent_privileges' do
    let(:path) { "/ai/duo_workflows/workflows/agent_privileges" }

    it 'returns a static set of privileges' do
      get api(path, user)

      expect(response).to have_gitlab_http_status(:ok)

      all_privileges_count = ::Ai::DuoWorkflows::Workflow::AgentPrivileges::ALL_PRIVILEGES.count
      expect(json_response['all_privileges'].count).to eq(all_privileges_count)

      privilege1 = json_response['all_privileges'][0]
      expect(privilege1['id']).to eq(1)
      expect(privilege1['name']).to eq('read_write_files')
      expect(privilege1['description']).to eq('Allow local filesystem read/write access')
      expect(privilege1['default_enabled']).to eq(true)

      privilege4 = json_response['all_privileges'][3]
      expect(privilege4['id']).to eq(4)
      expect(privilege4['name']).to eq('run_commands')
      expect(privilege4['description']).to eq('Allow running any commands')
      expect(privilege4['default_enabled']).to eq(false)
    end
  end
end
