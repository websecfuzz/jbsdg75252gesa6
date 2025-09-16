# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Dependencies, feature_category: :dependency_management do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user) }

  let_it_be(:occurrences) { create_list(:sbom_occurrence, 2, :with_vulnerabilities, :mit, project: project) }

  describe "GET /projects/:id/dependencies" do
    subject(:request) { get api("/projects/#{project.id}/dependencies", user), params: params }

    let(:params) { {} }
    let(:snowplow_standard_context_params) { { user: user, project: project, namespace: project.namespace } }

    before do
      stub_licensed_features(dependency_scanning: true, license_scanning: true, security_dashboard: true)
    end

    it_behaves_like 'a gitlab tracking event', described_class.name, 'view_dependencies'

    shared_examples 'does not have N+1 queries' do
      it 'does not have N+1 queries' do
        def go
          get api("/projects/#{project.id}/dependencies", user), params: params
        end

        control = ::ActiveRecord::QueryRecorder.new { go }

        create(:sbom_occurrence, :with_vulnerabilities, :mit, project: project)

        expect { go }.not_to exceed_query_limit(control)
      end
    end

    def json_dependency(occurrence)
      vulnerabilities = occurrence.vulnerabilities.map do |vulnerability|
        {
          'id' => vulnerability.id,
          'name' => vulnerability.title,
          'severity' => vulnerability.severity,
          'url' => end_with("/security/vulnerabilities/#{vulnerability.id}")
        }
      end

      {
        'name' => occurrence.name,
        'version' => occurrence.version,
        'package_manager' => occurrence.package_manager,
        'dependency_file_path' => occurrence.input_file_path,
        'vulnerabilities' => match_array(vulnerabilities),
        'licenses' => match_array(occurrence.licenses)
      }
    end

    context 'with an authorized user with proper permissions' do
      before do
        project.add_developer(user)
        request
      end

      it_behaves_like 'does not have N+1 queries'

      it 'returns paginated dependencies' do
        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/dependencies', dir: 'ee')
        expect(response).to include_pagination_headers

        expected_dependencies = occurrences.map { |occurrence| json_dependency(occurrence) }

        expect(json_response).to match(expected_dependencies)
      end

      context 'with nil package_manager' do
        let(:params) { { package_manager: nil } }

        it 'does not 500' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/dependencies', dir: 'ee')
        end
      end

      context 'with filter options' do
        let_it_be(:yarn_occurrence) { create(:sbom_occurrence, package_manager: 'yarn', project: project) }

        let(:params) { { package_manager: 'yarn' } }

        it 'returns yarn dependencies' do
          expect(json_response).to match([json_dependency(yarn_occurrence)])
        end

        context 'with wrong key' do
          let(:params) { { package_manager: %w[nray yarn] } }

          it 'returns error message' do
            expect(json_response['error']).to eq('package_manager does not have a valid value')
          end
        end
      end

      context 'with pagination params' do
        let(:params) { { per_page: 1, page: 2 } }

        it 'returns paginated dependencies' do
          expect(response).to match_response_schema('public_api/v4/dependencies', dir: 'ee')
          expect(response).to include_pagination_headers

          expect(json_response.length).to eq(1)
        end
      end
    end

    context 'without permissions to see vulnerabilities' do
      it 'returns empty vulnerabilities' do
        request

        expect(json_response.first['vulnerabilities']).to be_nil
      end

      it_behaves_like 'does not have N+1 queries'
    end

    context 'without permissions to see licenses' do
      before do
        # The only way a user can access this API but not license scanning results is when the feature is disabled
        stub_licensed_features(dependency_scanning: true, license_scanning: false, security_dashboard: true)
      end

      it 'returns empty licenses' do
        request

        expect(json_response.first['licenses']).to be_nil
      end
    end

    context 'with authorized user without read permissions' do
      let(:project) { create(:project, :private) }

      before do
        project.add_guest(user)
        request
      end

      it 'responds with 403 Forbidden' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with no project access' do
      let(:project) { create(:project, :private) }

      before do
        request
      end

      it 'responds with 404 Not Found' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
