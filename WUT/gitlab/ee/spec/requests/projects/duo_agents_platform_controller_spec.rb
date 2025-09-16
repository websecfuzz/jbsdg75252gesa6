# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects::DuoAgentsPlatform', type: :request, feature_category: :duo_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  before_all do
    project.add_developer(user)
  end

  before do
    sign_in(user)
  end

  describe 'GET /:namespace/:project/-/agents' do
    before do
      stub_feature_flags(duo_workflow_in_ci: true)
    end

    context 'when ::Ai::DuoWorkflow is enabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
      end

      it 'renders successfully' do
        get project_automate_agent_sessions_path(project)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when ::Ai::DuoWorkflow is disabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(false)
      end

      it 'returns 404' do
        get project_automate_agent_sessions_path(project)
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when duo_workflow_in_ci feature is disabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
        stub_feature_flags(duo_workflow_in_ci: false)
      end

      it 'returns 404' do
        get project_automate_agent_sessions_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
