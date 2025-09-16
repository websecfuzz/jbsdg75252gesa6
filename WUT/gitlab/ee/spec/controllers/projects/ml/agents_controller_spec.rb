# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Ml::AgentsController, feature_category: :mlops do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { project.first_owner }

  let(:read_ai_agents) { true }

  before do
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?)
                        .with(user, :read_ai_agents, project)
                        .and_return(read_ai_agents)

    sign_in(user)
  end

  describe 'GET index' do
    subject(:index_request) do
      get :index, params: { namespace_id: project.namespace, project_id: project }
      response
    end

    it 'renders the template' do
      expect(index_request).to render_template(:index)
    end

    context 'when user does not have access' do
      let(:read_ai_agents) { false }

      it 'renders 404' do
        expect(index_request).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
