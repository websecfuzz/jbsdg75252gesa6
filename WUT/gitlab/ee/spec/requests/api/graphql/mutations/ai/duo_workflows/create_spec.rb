# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AiDuoWorkflowCreate', feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, group: group, developers: current_user) }

  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, namespace: group)
  end

  let_it_be(:add_on_assignment) do
    create(:gitlab_subscription_user_add_on_assignment, user: current_user, add_on_purchase: add_on_purchase)
  end

  let(:workflow_type) { "default" }
  let(:input) do
    {
      project_id: project.to_global_id,
      goal: "Automate PR reviews",
      agent_privileges: [1, 2, 3],
      pre_approved_agent_privileges: [1],
      workflow_definition: workflow_type,
      allow_agent_to_request_user: true,
      environment: 'WEB'
    }
  end

  let(:mutation) do
    graphql_mutation(:ai_duo_workflow_create, input,
      <<-QL
        errors
        workflow {
          id
        }
      QL
    )
  end

  let(:mutation_response) { graphql_mutation_response(:ai_duo_workflow_create) }

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(ai_workflows: true, agentic_chat: true, ai_chat: true)
    project.root_ancestor.update!(experiment_features_enabled: true)
  end

  context 'when user is authorized', :saas do
    where(:workflow_type) do
      %w[default chat]
    end

    with_them do
      it 'creates a new workflow' do
        expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).with(
          project: project,
          current_user: current_user,
          params: {
            project_id: project.id,
            goal: "Automate PR reviews",
            agent_privileges: [1, 2, 3],
            pre_approved_agent_privileges: [1],
            workflow_definition: workflow_type,
            allow_agent_to_request_user: true,
            environment: 'web'
          }
        ).and_call_original

        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)

        workflow = ::Ai::DuoWorkflows::Workflow.last
        expect(mutation_response['workflow']['id']).to eq("gid://gitlab/Ai::DuoWorkflows::Workflow/#{workflow.id}")
        expect(mutation_response['errors']).to be_empty
      end
    end
  end

  context 'when the service returns an error', :saas do
    it 'returns the error message' do
      service_result = {
        status: :error,
        message: 'Failed to create workflow'
      }

      service = instance_double(::Ai::DuoWorkflows::CreateWorkflowService, execute: service_result)
      allow(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).and_return(service)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['workflow']).to be_nil
      expect(mutation_response['errors']).to eq(['Failed to create workflow'])
    end
  end

  context 'when a user is not authorized to use the feature' do
    where(:workflow_type) do
      %w[default chat unknown]
    end

    with_them do
      before do
        post_graphql_mutation(mutation, current_user: current_user)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end
end
