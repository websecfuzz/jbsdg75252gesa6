# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectsController, :with_license, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:project) { create(:project, maintainers: user) }

  before do
    sign_in(user)
  end

  context 'when Amazon Q is connected' do
    let_it_be(:integration) { create(:amazon_q_integration, instance: false, project: project) }

    let(:params) do
      {
        project: {
          amazon_q_auto_review_enabled: true,
          project_setting_attributes: { duo_features_enabled: 'true' }
        }
      }
    end

    before do
      allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
    end

    it 'changes auto_review_enabled field of the integration' do
      expect { put project_url(project, params) }.to change {
        project.amazon_q_integration.reload.auto_review_enabled
      }.from(false).to(true)
    end
  end

  context 'when viewing the new page' do
    it 'is successful' do
      get new_project_url

      expect(response).to have_gitlab_http_status(:ok)
    end
  end
end
