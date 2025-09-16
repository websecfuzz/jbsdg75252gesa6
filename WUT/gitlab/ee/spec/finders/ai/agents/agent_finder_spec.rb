# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Agents::AgentFinder, feature_category: :mlops do
  let_it_be(:project1) { create(:project) }
  let_it_be(:project2) { create(:project) }
  let_it_be(:agent1) { create(:ai_agent, project: project1) }
  let_it_be(:agent2) { create(:ai_agent, project: project1) }
  let_it_be(:agent3) { create(:ai_agent, project: project2) }

  subject(:agents) { described_class.new(project1).execute }

  describe 'default params' do
    it 'returns agents belonging to the given project' do
      is_expected.to include(agent1)
      is_expected.to include(agent2)
    end

    it 'does not return agents belonging to a different project' do
      is_expected.not_to include(agent3)
    end
  end
end
