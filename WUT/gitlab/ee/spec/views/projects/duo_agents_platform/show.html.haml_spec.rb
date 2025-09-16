# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/duo_agents_platform/show', type: :view, feature_category: :duo_workflow do
  let_it_be(:project) { build_stubbed(:project) }

  before do
    assign(:project, project)
    allow(view).to receive(:project_automate_agent_sessions_path).with(project).and_return('/test-project/-/agents')
  end

  it 'renders the agents platform page container' do
    render

    expect(rendered).to have_css('#js-duo-agents-platform-page')
  end

  it 'calls the duo agents platform helper' do
    expect(view).to receive(:duo_agents_platform_data).with(project).and_call_original
    render
  end

  it 'includes the correct data attribute for base route' do
    render

    expect(rendered).to have_css(
      '#js-duo-agents-platform-page[data-agents-platform-base-route="/test-project/-/agents"]'
    )
  end
end
