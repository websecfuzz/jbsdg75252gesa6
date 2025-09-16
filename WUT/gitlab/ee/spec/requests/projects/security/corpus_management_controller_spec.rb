# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::CorpusManagementController, type: :request, feature_category: :fuzz_testing do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  describe 'GET #show' do
    before do
      stub_licensed_features(coverage_fuzzing: true)

      login_as(user)
    end

    include_context '"Security and compliance" permissions' do
      let(:valid_request) { get project_security_configuration_corpus_management_path(project) }

      before_request do
        project.add_developer(user)
      end
    end

    context 'feature available' do
      context 'user authorized' do
        before do
          project.add_developer(user)
        end

        it 'can access page' do
          get project_security_configuration_corpus_management_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'user not authorized' do
        before do
          project.add_guest(user)
        end

        it 'sees a 404 error' do
          get project_security_configuration_corpus_management_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'feature not available' do
      before do
        stub_licensed_features(coverage_fuzzing: false)

        project.add_developer(user)
      end

      context 'license doesnt\'t support the feature' do
        it 'sees a 404 error' do
          get project_security_configuration_corpus_management_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
