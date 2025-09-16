# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'Subscriptions::Ai::DuoWorkflows::WorkflowEventsUpdated', feature_category: :duo_workflow do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user) }
  let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
  let(:checkpoint) { create(:duo_workflows_checkpoint, project: project, workflow: workflow) }
  let(:subscription_query) do
    <<~SUBSCRIPTION
      subscription {
        workflowEventsUpdated(workflowId: \"#{workflow.to_gid}\") {
          checkpoint
          metadata
          errors
          workflowStatus
          executionStatus
        }
      }
    SUBSCRIPTION
  end

  let(:subscribe) do
    mock_channel = Graphql::Subscriptions::ActionCable::MockActionCable.get_mock_channel
    GitlabSchema.execute(subscription_query, context: { current_user: user, channel: mock_channel })
    mock_channel
  end

  let(:updated_workflow) { graphql_dig_at(graphql_data(response[:result]), :workflowEventsUpdated) }

  before do
    stub_const('GitlabSchema', Graphql::Subscriptions::ActionCable::MockGitlabSchema)
    Graphql::Subscriptions::ActionCable::MockActionCable.clear_mocks
  end

  subject(:response) do
    subscription_response do
      GraphqlTriggers.workflow_events_updated(checkpoint)
    end
  end

  context 'when duo workflow is not available' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(false)
    end

    it 'does not receive any data' do
      expect(response).to be_nil
    end
  end

  context "when duo workflow is available" do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
      allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    context 'when user is unauthorized' do
      before_all do
        project.add_guest(user)
      end

      it 'does not receive any data' do
        expect(response).to be_nil
      end
    end

    context 'when user is authorized' do
      before_all do
        project.add_developer(user)
      end

      it 'receives updated workflow_event data' do
        expect(updated_workflow['checkpoint']).to eq(checkpoint.checkpoint.to_json)
        expect(updated_workflow['metadata']).to eq(checkpoint.metadata.to_json)
        expect(updated_workflow['errors']).to eq([])
        expect(updated_workflow['workflowStatus']).to eq('CREATED')
        expect(updated_workflow['executionStatus']).to eq('Created')
      end

      context 'when duo_features_enabled settings is turned off' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
        end

        it 'does not receive any data' do
          expect(response).to be_nil
        end
      end
    end
  end

  def subscription_response
    subscription_channel = subscribe
    yield
    subscription_channel.mock_broadcasted_messages.first
  end
end
