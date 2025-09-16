# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying Duo Workflow Events', feature_category: :duo_workflow do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:workflow) { create(:duo_workflows_workflow, project: project, user: user, checkpoints: checkpoints) }
  let_it_be(:checkpoints) { create_list(:duo_workflows_checkpoint, 3, project: project) }

  let(:fields) do
    <<~GRAPHQL
      edges {
        node {
          timestamp,
          errors,
          checkpoint,
          metadata,
          parentTimestamp,
          workflowGoal,
          workflowDefinition
        }
    }
    GRAPHQL
  end

  let(:arguments) { { workflowId: global_id_of(workflow) } }
  let(:query) { graphql_query_for('duoWorkflowEvents', arguments, fields) }

  subject(:event_nodes) { graphql_data.dig('duoWorkflowEvents', 'edges') }

  context 'when user is not logged in' do
    it 'returns an empty array' do
      post_graphql(query, current_user: nil)

      expect(event_nodes).to be_empty
    end
  end

  context 'when user is logged in' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf  -- not the next instance
      allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    it 'returns user messages' do
      post_graphql(query, current_user: user)

      expect(event_nodes).not_to be_empty
      event_nodes.sort_by { |event_node| event_node['node']['timestamp'] }.each_with_index do |event_node, i|
        event = event_node['node']
        expect(event['errors']).to eq([])
        expect(event['checkpoint']).to eq(checkpoints[i].checkpoint.to_json)
        expect(event['metadata']).to eq(checkpoints[i].metadata.to_json)
        expect(event['timestamp']).to eq(Time.parse(checkpoints[i].thread_ts).iso8601)
        expect(event['parentTimestamp']).to eq(Time.parse(checkpoints[i].parent_ts).iso8601)
        expect(event['workflowGoal']).to eq("Fix pipeline")
        expect(event['workflowDefinition']).to eq("software_development")
      end
    end
  end
end
