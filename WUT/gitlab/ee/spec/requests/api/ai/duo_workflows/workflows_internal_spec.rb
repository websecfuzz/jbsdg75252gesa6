# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::WorkflowsInternal, feature_category: :duo_workflow do
  include HttpBasicAuthHelpers

  let_it_be(:ai_settings) { create(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }
  let_it_be(:group) { create(:group, ai_settings: ai_settings) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  let_it_be(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }
  let_it_be(:ai_workflows_oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }
  let_it_be(:workflow) do
    create(
      :duo_workflows_workflow,
      user: user,
      project: project,
      pre_approved_agent_privileges: [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
      agent_privileges: [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES]
    )
  end

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
    allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
    # rubocop:enable RSpec/AnyInstanceOf
  end

  describe 'POST /ai/duo_workflows/workflows/:id/checkpoints' do
    let(:current_time) { Time.current }
    let(:thread_ts) { current_time.to_s }
    let(:later_thread_ts) { (current_time + 1.second).to_s }
    let(:parent_ts) { (current_time - 1.second).to_s }
    let(:checkpoint) { { key: 'value' } }
    let(:metadata) { { key: 'value' } }
    let(:params) { { thread_ts: thread_ts, checkpoint: checkpoint, parent_ts: parent_ts, metadata: metadata } }
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints" }

    it 'allows creating multiple checkpoints for a workflow' do
      expect do
        post api(path, user), params: params
        expect(response).to have_gitlab_http_status(:created)

        post api(path, user), params: params.merge(thread_ts: later_thread_ts, parent_ts: thread_ts)
        expect(response).to have_gitlab_http_status(:created)
      end.to change { workflow.reload.checkpoints.count }.by(2)

      expect(json_response['id']).to eq(Ai::DuoWorkflows::Checkpoint.last.id.first)
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it 'is successful' do
        post api(path, oauth_access_token: ai_workflows_oauth_token),
          params: params.merge(thread_ts: later_thread_ts, parent_ts: thread_ts)

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    it 'fails if the thread_ts is an empty string' do
      post api(path, user), params: params.merge(thread_ts: '')
      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']).to include("can't be blank")
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id/checkpoints' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints" }

    it 'returns the checkpoints in descending order of thread_ts' do
      checkpoint1 = create(:duo_workflows_checkpoint, workflow: workflow)
      checkpoint2 = create(:duo_workflows_checkpoint, workflow: workflow)
      workflow.checkpoints << checkpoint1
      workflow.checkpoints << checkpoint2

      get api(path, user)
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to eq([checkpoint2.id.first, checkpoint1.id.first])
      expect(json_response.pluck('thread_ts')).to eq([checkpoint2.thread_ts, checkpoint1.thread_ts])
      expect(json_response.pluck('parent_ts')).to eq([checkpoint2.parent_ts, checkpoint1.parent_ts])
      expect(json_response[0]).to have_key('checkpoint')
      expect(json_response[0]).to have_key('metadata')
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id/checkpoints/:checkpoint_id' do
    it 'returns the checkpoint' do
      checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
      checkpoint_write = create(:duo_workflows_checkpoint_write, thread_ts: checkpoint.thread_ts,
        workflow: checkpoint.workflow)
      path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"

      get api(path, user)
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(checkpoint.id.first)
      expect(json_response['thread_ts']).to eq(checkpoint.thread_ts)
      expect(json_response['parent_ts']).to eq(checkpoint.parent_ts)
      expect(json_response).to have_key('checkpoint')
      expect(json_response).to have_key('metadata')
      expect(json_response['checkpoint_writes'][0]['id']).to eq(checkpoint_write.id)
    end

    context 'when a checkpoint from a workflow belongs to a different user' do
      it 'returns 404' do
        workflow = create(:duo_workflows_workflow, project: project)
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        create(:duo_workflows_checkpoint_write, thread_ts: checkpoint.thread_ts,
          workflow: checkpoint.workflow)
        path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"
        get api(path, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST /ai/duo_workflows/workflows/:id/checkpoint_writes_batch' do
    let(:params) do
      {
        thread_ts: 'checkpoint_id',
        checkpoint_writes: [task: 'id', idx: 0, channel: 'channel', write_type: 'type', data: 'data']
      }
    end

    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/checkpoint_writes_batch" }

    it 'allows updating a workflow' do
      post api(path, user), params: params

      expect(response).to have_gitlab_http_status(:success)
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with invalid input' do
      let(:params) do
        {
          thread_ts: 'checkpoint_id',
          checkpoint_writes: [task: '', idx: 0, channel: 'channel', write_type: 'type', data: 'data']
        }
      end

      it 'returns bad request' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.body).to eq({ message: "400 Bad request - Validation failed: Task can't be blank" }.to_json)
      end
    end
  end

  describe 'POST /ai/duo_workflows/workflows/:id/events' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events" }
    let(:correlation_id) { nil }
    let(:params) do
      {
        event_type: 'message',
        message: 'Hello, World!',
        correlation_id: correlation_id
      }
    end

    context 'when success' do
      it 'creates a new event' do
        expect do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { workflow.events.count }.by(1)
        expect(json_response['id']).to eq(Ai::DuoWorkflows::Event.last.id)
        expect(json_response['event_type']).to eq('message')
        expect(json_response['message']).to eq('Hello, World!')
        expect(json_response['event_status']).to eq('queued')
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is successful' do
          expect do
            post api(path, oauth_access_token: ai_workflows_oauth_token), params: params
            expect(response).to have_gitlab_http_status(:created)
          end.to change { workflow.events.count }.by(1)
        end
      end

      context 'when correlation_id is provided' do
        let(:correlation_id) { '123e4567-e89b-12d3-a456-426614174000' }

        it 'creates an event with the provided correlation_id' do
          expect do
            post api(path, oauth_access_token: ai_workflows_oauth_token), params: params
            expect(response).to have_gitlab_http_status(:created)
          end.to change { workflow.events.count }.by(1)
          expect(json_response['correlation_id']).to eq(correlation_id)
        end
      end

      context 'when an invalid correlation_id is provided' do
        let(:correlation_id) { 'invalid_id' }

        it 'rejects an invalid correlation_id' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('correlation_id is invalid')
        end
      end
    end

    context 'when required parameters are missing' do
      it 'returns bad request when event_type is missing' do
        post api(path, user), params: params.except(:event_type)
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("event_type is missing")
      end

      it 'returns bad request when message is missing' do
        post api(path, user), params: params.except(:message)
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("message is missing")
      end
    end

    context 'when invalid event_type is provided' do
      it 'returns bad request' do
        post api(path, user), params: params.merge(event_type: 'invalid_event_type')
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("event_type does not have a valid value")
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        post api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id/events' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events" }

    it 'returns queued events for the workflow' do
      event1 = create(:duo_workflows_event, workflow: workflow, event_status: :queued)
      event2 = create(:duo_workflows_event, workflow: workflow, event_status: :queued)

      get api(path, user)
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.size).to eq(2)
      # rubocop:disable Rails/Pluck -- json_response is an array of hashes, we can't use pluck
      expect(json_response.map { |e| e['id'] }).to contain_exactly(event1.id, event2.id)
      expect(json_response.map { |e| e['event_status'] }).to all(eq('queued'))
      # rubocop:enable Rails/Pluck
    end

    it 'returns empty array if no queued events' do
      create(:duo_workflows_event, workflow: workflow, event_status: :delivered)

      get api(path, user)
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to be_empty
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        get api(path, user)
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PUT /ai/duo_workflows/workflows/:id/events/:event_id' do
    let(:event) { create(:duo_workflows_event, workflow: workflow, event_status: :queued) }
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events/#{event.id}" }
    let(:params) { { event_status: 'delivered' } }

    context 'when success' do
      it 'updates the event status' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(event.id)
        expect(json_response['event_status']).to eq('delivered')
        expect(event.reload.event_status).to eq('delivered')
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is successful' do
          put api(path, oauth_access_token: ai_workflows_oauth_token), params: params
          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when invalid event_status is provided' do
      it 'returns bad request' do
        put api(path, user), params: { event_status: 'InvalidStatus' }
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("event_status does not have a valid value")
      end
    end

    context 'when the event does not exist' do
      let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events/0" }

      it 'returns 404' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with an event belonging to a different workflow' do
      let(:other_workflow) { create(:duo_workflows_workflow, user: user, project: project) }
      let(:event) { create(:duo_workflows_event, workflow: other_workflow) }

      it 'returns 404' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}" }

    before do
      allow(Gitlab::AiGateway)
        .to receive(:public_headers)
        .with(user: user, service_name: :duo_workflow)
        .and_return({ 'x-gitlab-enabled-feature-flags' => 'test-feature' })
    end

    it 'returns the Ai::DuoWorkflows::Workflow' do
      get api(path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(workflow.id)
      expect(json_response['project_id']).to eq(project.id)
      expect(json_response['agent_privileges']).to eq(workflow.agent_privileges)
      expect(json_response['agent_privileges_names']).to eq(["read_write_files"])
      expect(json_response['pre_approved_agent_privileges']).to eq(workflow.pre_approved_agent_privileges)
      expect(json_response['pre_approved_agent_privileges_names']).to eq(["read_write_files"])
      expect(json_response['allow_agent_to_request_user']).to be(true)
      expect(json_response['mcp_enabled']).to be(true)
      expect(json_response['gitlab_url']).to eq(Gitlab.config.gitlab.url)
      expect(json_response['status']).to eq("created")
      expect(response.headers['X-Gitlab-Enabled-Feature-Flags']).to include('test-feature')
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it 'returns the Ai::DuoWorkflows::Workflow' do
        get api(path, oauth_access_token: ai_workflows_oauth_token)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(workflow.id)
      end
    end

    context 'when authenticated with a composite identity token' do
      let_it_be(:service_account) do
        create(:user, :service_account, developer_of: workflow.project, composite_identity_enforced: true)
      end

      let_it_be(:composite_oauth_token) do
        create(:oauth_access_token, user: service_account, scopes: ['ai_workflows', "user:#{user.id}"])
      end

      before do
        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(user: service_account, service_name: :duo_workflow)
          .and_return({})
      end

      it 'returns the Ai::DuoWorkflows::Workflow' do
        get api(path, oauth_access_token: composite_oauth_token)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(workflow.id)
      end
    end

    context 'when duo_features_enabled settings is turned off' do
      before do
        workflow.project.project_setting.update!(duo_features_enabled: false)
        workflow.project.reload
      end

      it 'returns forbidden' do
        get api(path, user)
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        get api(path, user)
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /ai/duo_workflows/workflows/:id' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}" }

    context 'when update workflow status service returns error' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::UpdateWorkflowStatusService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(reason: :bad_request,
            message: 'Cannot update workflow status'))
        end
      end

      it 'returns http error status and error message' do
        patch api(path, user), params: { status_event: "finish" }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Cannot update workflow status')
      end
    end

    context 'when update workflow status service returns success' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::UpdateWorkflowStatusService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: { workflow: workflow },
            message: 'Workflow status updated'))
        end
      end

      it 'returns http status ok' do
        patch api(path, user), params: { status_event: "finish" }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['workflow']['id']).to eq(workflow.id)
      end
    end

    context 'when duo_features_enabled settings is turned off' do
      before do
        workflow.project.project_setting.update!(duo_features_enabled: false)
        workflow.project.reload
      end

      it 'returns forbidden' do
        patch api(path, user), params: { status_event: "finish" }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
