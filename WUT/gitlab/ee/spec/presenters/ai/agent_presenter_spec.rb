# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AgentPresenter, feature_category: :mlops do
  let(:project) { build_stubbed(:project) }
  let(:agent) { build_stubbed(:ai_agent, project: project) }

  describe '#route_id' do
    subject { agent.present.route_id }

    it { is_expected.to eq(agent.id) }
  end
end
