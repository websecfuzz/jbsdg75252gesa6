# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::MattermostsController do
  let!(:project) { create(:project) }
  let!(:user) { create(:user) }

  before do
    project.add_maintainer(user)
    sign_in(user)
  end

  describe 'GET #new' do
    before do
      allow_next_instance_of(Integrations::MattermostSlashCommands) do |instance|
        allow(instance).to receive(:list_teams).and_return([])
      end
    end

    it 'accepts the request' do
      get :new, params: {
        namespace_id: project.namespace.to_param,
        project_id: project
      }

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe 'POST #create' do
    let(:mattermost_params) { { trigger: 'http://localhost:3000/trigger', team_id: 'abc' } }

    subject do
      post :create, params: {
        namespace_id: project.namespace.to_param,
        project_id: project,
        mattermost: mattermost_params
      }
    end

    context 'when integration is nil' do
      before do
        # rubocop:disable RSpec/AnyInstanceOf -- next_instance does not work in this scenario
        allow_any_instance_of(Project).to receive(:find_or_initialize_integration).and_return(nil)
        # rubocop:enable RSpec/AnyInstanceOf
      end

      it 'renders 404' do
        expect(subject).to have_gitlab_http_status(:not_found)
      end
    end

    context 'no request can be made to mattermost' do
      it 'shows the error' do
        allow_next_instance_of(Integrations::MattermostSlashCommands) do |instance|
          allow(instance).to receive(:configure).and_return([false, "error message"])
        end

        expect(subject).to redirect_to(new_project_mattermost_url(project))
      end
    end

    context 'the request is succesull' do
      before do
        allow_next_instance_of(::Mattermost::Command) do |instance|
          allow(instance).to receive(:create).and_return('token')
        end
      end

      it 'redirects to the new page' do
        subject
        integration = project.integrations.last

        expect(subject).to redirect_to(edit_project_settings_integration_path(project, integration))
      end
    end
  end
end
