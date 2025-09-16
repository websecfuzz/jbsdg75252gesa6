# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Agents::FindAgentResolver, feature_category: :mlops do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:project) { create(:project) }
    let_it_be(:agents) { create_list(:ai_agent, 2, project: project) }
    let_it_be(:agent_in_another_project) { create(:ai_agent) }
    let_it_be(:user) { project.owner }

    let(:read_ai_agents) { true }

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
                          .with(user, :read_ai_agents, project)
                          .and_return(read_ai_agents)
    end

    subject(:resolve_agents) do
      force(resolve(described_class, obj: project, ctx: { current_user: user }))&.to_a
    end

    context 'when user is allowed and agents exists' do
      it { is_expected.to eq(agents.reverse) }

      it 'only passes name, sort_by and order to finder' do
        expect(::Ai::Agents::AgentFinder).to receive(:new)
                                                 .with(project)
                                                 .and_call_original

        resolve_agents
      end
    end

    context 'when user does not have permission' do
      let(:read_ai_agents) { false }

      it { is_expected.to be_nil }
    end
  end
end
