# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Projects::DuoAgentsPlatformHelper, feature_category: :duo_workflow do
  include Rails.application.routes.url_helpers

  let_it_be(:group) { build_stubbed(:group, name: 'Test Group') }
  let_it_be(:project) { build_stubbed(:project, name: 'Test Project', group: group) }

  before do
    helper.instance_variable_set(:@project, project)
  end

  describe '#duo_agents_platform_data' do
    subject(:helper_data) { helper.duo_agents_platform_data(project) }

    before do
      allow(helper).to receive(:project_automate_agent_sessions_path).with(project).and_return('/test-project/-/agents')
      allow(helper).to receive(:image_path).with(
        'illustrations/empty-state/empty-pipeline-md.svg')
        .and_return('/assets/illustrations/empty-state/empty-pipeline-md.svg'
                   )
    end

    it 'returns the expected data hash' do
      expected_data = {
        agents_platform_base_route: '/test-project/-/agents',
        project_path: project.full_path,
        project_id: project.id,
        duo_agents_invoke_path: api_v4_ai_duo_workflows_workflows_path,
        empty_state_illustration_path: '/assets/illustrations/empty-state/empty-pipeline-md.svg'
      }

      expect(helper_data).to eq(expected_data)
    end
  end
end
