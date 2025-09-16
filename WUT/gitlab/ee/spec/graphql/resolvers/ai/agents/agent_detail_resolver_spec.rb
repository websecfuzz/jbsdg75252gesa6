# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Agents::AgentDetailResolver, feature_category: :mlops do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:project) { create(:project) }
    let_it_be(:agent) { create(:ai_agent, project: project) }
    let_it_be(:agent_in_another_project) { create(:ai_agent) }
    let_it_be(:user) { project.owner }
    let_it_be(:other_user) { create(:user) }

    let(:args) { { id: global_id_of(agent) } }

    subject(:resolve_agents) do
      force(resolve(described_class, ctx: { current_user: user }, args: args))
    end

    before do
      stub_licensed_features(ai_agents: true)
    end

    context 'when user is allowed and agent exists' do
      it { is_expected.to eq(agent) }

      context 'when user is nil' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    context 'when user does not have permission' do
      let(:user) { other_user }

      it { is_expected.to be_nil }
    end

    context 'when the agent does not exist' do
      let(:args) { { id: global_id_of(id: non_existing_record_id, model_name: 'Ai::Agent') } }

      it { is_expected.to be_nil }
    end
  end
end
