# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying Duo Workflows Workflows', feature_category: :duo_workflow do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:project_2) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:workflow_without_environment) do
    create(:duo_workflows_workflow, project: project, user: user, created_at: 1.day.ago)
  end

  let_it_be(:workflow_with_ide_environment) do
    create(:duo_workflows_workflow, environment: :ide, project: project, user: user, created_at: 1.day.ago)
  end

  let_it_be(:workflow_with_web_environment) do
    create(:duo_workflows_workflow, environment: :web, project: project, user: user, created_at: 1.day.ago)
  end

  let_it_be(:archived_workflow) do
    create(:duo_workflows_workflow,
      project: project,
      user: user,
      created_at: (Ai::DuoWorkflows::CHECKPOINT_RETENTION_DAYS + 1).days.ago)
  end

  let_it_be(:stalled_workflow) do
    workflow = create(:duo_workflows_workflow, project: project, user: user)
    workflow.start!
    workflow
  end

  let_it_be(:non_stalled_workflow_with_checkpoint) do
    workflow = create(:duo_workflows_workflow, project: project, user: user)
    workflow.start!
    create(:duo_workflows_checkpoint, workflow: workflow, project: workflow.project)
    workflow
  end

  let_it_be(:workflows) do
    [
      workflow_without_environment,
      workflow_with_ide_environment,
      workflow_with_web_environment,
      archived_workflow,
      stalled_workflow,
      non_stalled_workflow_with_checkpoint
    ]
  end

  let_it_be(:workflows_project_2) { create_list(:duo_workflows_workflow, 2, project: project_2, user: user) }
  let_it_be(:workflows_for_different_user) { create_list(:duo_workflows_workflow, 4, project: project) }
  let(:all_project_workflows) { workflows + workflows_project_2 }

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id,
        userId,
        projectId,
        project {
          id
          name
        },
        humanStatus,
        goal,
        workflowDefinition,
        environment,
        createdAt,
        updatedAt,
        status,
        statusName,
        agentPrivilegesNames,
        preApprovedAgentPrivilegesNames,
        mcpEnabled
        allowAgentToRequestUser
        archived
        stalled
        firstCheckpoint {
          checkpoint
          metadata
          timestamp
          workflowStatus
        }
      }
    GRAPHQL
  end

  let(:variables) { nil }
  let(:current_user) { user }
  let(:query) { graphql_query_for('duoWorkflowWorkflows', variables, fields) }

  # Create a checkpoint for the first workflow to test the firstCheckpoint field
  let_it_be(:checkpoint) do
    workflow = workflows.first
    create(:duo_workflows_checkpoint, workflow: workflow, project: workflow.project)
  end

  before do
    # Set up MCP enabled for testing
    allow_next_instance_of(Namespace) do |instance|
      allow(instance).to receive(:duo_workflow_mcp_enabled).and_return(true)
    end

    # Allow StageCheck for any project
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(false)
  end

  subject(:returned_workflows) { graphql_data.dig('duoWorkflowWorkflows', 'nodes') }

  context 'when duo workflow is not available' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(false)
    end

    it 'returns an empty array' do
      post_graphql(query, current_user: nil)

      expect(returned_workflows).to be_empty
    end
  end

  context 'when duo workflow is available' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(true)
    end

    context 'when user is not logged in' do
      it 'returns an empty array' do
        post_graphql(query, current_user: nil)

        expect(returned_workflows).to be_empty
      end
    end

    context 'when the user does not have access to the project' do
      let(:current_user) { create(:user) }

      it 'returns an empty array', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_nil
        expect(returned_workflows).to be_empty
      end
    end

    context 'when the user has access to the project and is allowed to use duo_agent_platform' do
      before do
        # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
        allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
        # rubocop:enable RSpec/AnyInstanceOf
      end

      it 'returns the workflows' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_nil

        expect(returned_workflows).not_to be_empty
        expect(returned_workflows.length).to eq(all_project_workflows.length)
        all_project_workflows_by_id = all_project_workflows.index_by { |w| w.to_global_id.to_s }
        returned_workflows.each do |returned_workflow|
          matching_workflow = all_project_workflows_by_id[returned_workflow['id']]
          expect(matching_workflow).not_to be_nil
          expect(returned_workflow['userId']).to eq(user.to_global_id.to_s)
          expect(returned_workflow['projectId']).to eq(matching_workflow.project.to_global_id.to_s)
          expect(returned_workflow['project']['id']).to eq(matching_workflow.project.to_global_id.to_s)
          expect(returned_workflow['project']['name']).to eq(matching_workflow.project.name)
          expect(returned_workflow['humanStatus']).to eq(matching_workflow.human_status_name)
          expect(returned_workflow['createdAt']).to eq(matching_workflow.created_at.iso8601)
          expect(returned_workflow['updatedAt']).to eq(matching_workflow.updated_at.iso8601)
          expect(returned_workflow['goal']).to eq("Fix pipeline")
          expect(returned_workflow['workflowDefinition']).to eq("software_development")
          expected_status = case matching_workflow
                            when stalled_workflow, non_stalled_workflow_with_checkpoint
                              "RUNNING"
                            else
                              "CREATED"
                            end
          expect(returned_workflow['status']).to eq(expected_status)
          expect(returned_workflow['statusName']).to eq(matching_workflow.status_name.to_s)
          expect(returned_workflow['agentPrivilegesNames']).to eq(["read_write_files"])
          expect(returned_workflow['preApprovedAgentPrivilegesNames']).to eq([])
          expect(returned_workflow['mcpEnabled']).to eq(
            matching_workflow.project.root_ancestor.duo_workflow_mcp_enabled)
          expect(returned_workflow['allowAgentToRequestUser']).to eq(matching_workflow.allow_agent_to_request_user)

          expect(returned_workflow).to have_key('firstCheckpoint')
        end
      end

      context 'with the project_path argument' do
        let(:variables) { { project_path: project.full_path } }

        it 'returns only the workflows for that project owned by that user', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(workflows.length)
          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['userId']).to eq(user.to_global_id.to_s)
          end
        end
      end

      context 'with the environment argument' do
        context 'when environment argument is web' do
          let(:variables) { { environment: :WEB } }

          it 'returns only workflows with web environment', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(1)
            returned_workflows.each do |returned_workflow|
              expect(returned_workflow['environment']).to eq("WEB")
            end
          end
        end

        context 'when environment argument is not given' do
          let(:variables) { {} }

          it 'returns workflows independent of environment', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length)
          end
        end
      end

      context 'with the workflow_id argument' do
        let(:specific_workflow) { workflows.first }
        let(:variables) { { workflow_id: specific_workflow.to_global_id.to_s } }

        before do
          # Ensure the checkpoint is associated with the specific workflow
          specific_workflow.reload
        end

        it 'returns only the specified workflow', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(1)
          expect(returned_workflows.first['id']).to eq(specific_workflow.to_global_id.to_s)
          expect(returned_workflows.first['userId']).to eq(user.to_global_id.to_s)
          expect(returned_workflows.first['projectId']).to eq(specific_workflow.project.to_global_id.to_s)
          expect(returned_workflows.first['project']['id']).to eq(specific_workflow.project.to_global_id.to_s)
          expect(returned_workflows.first['project']['name']).to eq(specific_workflow.project.name)
          expect(returned_workflows.first['goal']).to eq("Fix pipeline")
          expect(returned_workflows.first['workflowDefinition']).to eq("software_development")
          expect(returned_workflows.first['status']).to eq("CREATED")
          expect(returned_workflows.first['statusName']).to eq(specific_workflow.status_name.to_s)
          expect(returned_workflows.first['agentPrivilegesNames']).to eq(["read_write_files"])
          expect(returned_workflows.first['preApprovedAgentPrivilegesNames']).to eq([])
          expect(returned_workflows.first['mcpEnabled']).to eq(
            specific_workflow.project.root_ancestor.duo_workflow_mcp_enabled)
          expect(returned_workflows.first['allowAgentToRequestUser']).to eq(
            specific_workflow.allow_agent_to_request_user
          )
          expect(returned_workflows.first).to have_key('firstCheckpoint')
        end

        context 'when the user does not have access to the workflow' do
          let(:specific_workflow) { workflows_for_different_user.first }
          let(:current_user) { create(:user) }

          it 'returns a permission error', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            error_message = json_response['errors'].first['message']
            expect(error_message).to eq("You don't have permission to access this workflow")
          end
        end

        context 'when the workflow does not exist' do
          let(:variables) { { workflow_id: "gid://gitlab/Ai::DuoWorkflows::Workflow/#{non_existent_record_id}" } }
          let(:non_existent_record_id) { 999999 }

          it 'returns a resource not available error', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            error_message = json_response['errors'].first['message']
            expect(error_message).to eq('Workflow not found')
          end
        end
      end

      context 'with the sort argument' do
        context 'when :created_asc' do
          let(:variables) { { sort: :created_asc } }

          it 'returns the workflows oldest first', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length)
            expect(returned_workflows.first['createdAt']).to be < returned_workflows.last['createdAt']
          end
        end

        context 'when :created_desc' do
          let(:variables) { { sort: :created_desc } }

          it 'returns the workflows latest first', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length)
            expect(returned_workflows.first['createdAt']).to be > returned_workflows.last['createdAt']
          end
        end
      end

      context 'with archived and stalled fields' do
        it 'returns the correct archived and stalled values', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          returned_workflows_by_id = returned_workflows.index_by { |w| w['id'] }

          # Check archived workflow
          archived_result = returned_workflows_by_id[archived_workflow.to_global_id.to_s]
          expect(archived_result).not_to be_nil
          expect(archived_result['archived']).to be(true)
          expect(archived_result['stalled']).to be(false) # archived workflows in created state are not stalled

          # Check stalled workflow (running state with no checkpoints)
          stalled_result = returned_workflows_by_id[stalled_workflow.to_global_id.to_s]
          expect(stalled_result).not_to be_nil
          expect(stalled_result['archived']).to be(false)
          expect(stalled_result['stalled']).to be(true)

          # Check non-stalled workflow with checkpoint
          non_stalled_result = returned_workflows_by_id[non_stalled_workflow_with_checkpoint.to_global_id.to_s]
          expect(non_stalled_result).not_to be_nil
          expect(non_stalled_result['archived']).to be(false)
          expect(non_stalled_result['stalled']).to be(false)

          # Check regular workflows (not archived, in created state so not stalled)
          [workflow_without_environment, workflow_with_ide_environment,
            workflow_with_web_environment].each do |workflow|
            result = returned_workflows_by_id[workflow.to_global_id.to_s]
            expect(result).not_to be_nil
            expect(result['archived']).to be(false)
            expect(result['stalled']).to be(false)
          end
        end
      end

      context 'with the workflow_id argument for archived workflow' do
        let(:variables) { { workflow_id: archived_workflow.to_global_id.to_s } }

        it 'returns the archived workflow with correct archived status', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(1)
          expect(returned_workflows.first['id']).to eq(archived_workflow.to_global_id.to_s)
          expect(returned_workflows.first['archived']).to be(true)
          expect(returned_workflows.first['stalled']).to be(false)
        end
      end

      context 'with the workflow_id argument for stalled workflow' do
        let(:variables) { { workflow_id: stalled_workflow.to_global_id.to_s } }

        it 'returns the stalled workflow with correct stalled status', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(1)
          expect(returned_workflows.first['id']).to eq(stalled_workflow.to_global_id.to_s)
          expect(returned_workflows.first['archived']).to be(false)
          expect(returned_workflows.first['stalled']).to be(true)
        end
      end
    end

    context 'when duo_features_enabled settings is turned off' do
      before do
        project.project_setting.update!(duo_features_enabled: false)
        project_2.project_setting.update!(duo_features_enabled: false)
      end

      it 'returns an empty array' do
        post_graphql(query, current_user: user)

        expect(returned_workflows).to be_empty
      end
    end
  end
end
