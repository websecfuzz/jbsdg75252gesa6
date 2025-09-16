# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Agents', :js, feature_category: :mlops do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, namespace: project.namespace) }
  let_it_be(:project_member) { create(:project_member, :reporter, project: project, user: user) }

  before do
    stub_licensed_features(ai_agents: true)
    stub_feature_flags(agent_registry: true)
    sign_in(user)
  end

  context 'with an authenticated user with reporter permissions' do
    it 'shows the AI Agents empty state screen when no agents exist' do
      visit project_ml_agents_path(project)
      expect(page).to have_content('Create your own AI Agents')
    end

    it 'shows a list of AI Agents when they exist for a project' do
      create(:ai_agent, name: "my-agent", project: project)

      visit project_ml_agents_path(project)

      expect(page).to have_content('AI Agents')
      expect(page).to have_content('my-agent')
    end

    it 'shows the view screen when clicking on an agent name' do
      agent1 = create(:ai_agent, name: "my-agent", project: project)
      create(:ai_agent_version, agent: agent1, project: project)
      create(:ai_agent, name: "my-agent-2", project: project)

      visit project_ml_agents_path(project)

      expect(page).to have_content('AI Agents')
      expect(page).to have_content('my-agent')
      expect(page).to have_content('my-agent-2')

      click_on('my-agent')

      expect(page).to have_content(agent1.name)
    end

    it 'shows the create screen when the button is clicked' do
      visit project_ml_agents_path(project)
      expect(page).to have_content('Create your own AI Agents')

      click_on('Create agent')

      expect(page).to have_content('Agent name')
      expect(page).to have_content('Prompt')
    end

    it 'creates an AI agent when the data is supplied and the button clicked' do
      visit new_project_ml_agent_path(project)
      expect(page).to have_content('New agent')
      expect(page).to have_content('Agent name')
      expect(page).to have_content('Prompt')

      find('input[data-testid="agent-name"]').set('my-agent-name')
      find('textarea[data-testid="agent-prompt"]').set('my-agent-prompt')

      click_on('Create agent')

      expect(page).to have_content("my-agent-name")
      expect(page).to have_content("Try out your agent")
      expect(page).not_to have_content('New agent')
      expect(page).not_to have_content('Agent name')
      expect(page).not_to have_content('Prompt')
    end
  end
end
