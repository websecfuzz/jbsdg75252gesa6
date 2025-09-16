# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Explore::DependenciesController, :with_current_organization, feature_category: :dependency_management do
  describe 'GET #index' do
    describe 'GET index.html' do
      subject { get explore_dependencies_path }

      context 'when dependency scanning is available' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        context 'when user is admin', :enable_admin_mode do
          let_it_be(:user) { create(:user, :admin, organizations: [current_organization]) }

          before do
            sign_in(user)
          end

          include_examples 'returning response status', :ok

          context 'when the feature flag is disabled' do
            before do
              stub_feature_flags(explore_dependencies: false)
            end

            include_examples 'returning response status', :not_found
          end
        end

        context 'when user is not admin' do
          let_it_be(:user) { create(:user, organizations: [current_organization]) }

          before do
            sign_in(user)
          end

          include_examples 'returning response status', :forbidden
        end

        context 'when a user is not logged in' do
          include_examples 'returning response status', :not_found
        end
      end

      context 'when dependency scanning is not available' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        include_examples 'returning response status', :not_found

        context 'when user is admin', :enable_admin_mode do
          let_it_be(:user) { create(:user, :admin, organizations: [current_organization]) }

          before do
            sign_in(user)
          end

          include_examples 'returning response status', :forbidden
        end
      end
    end

    describe 'GET index.json', :enable_admin_mode do
      subject { get explore_dependencies_path, as: :json }

      context 'when dependency scanning is available' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        context 'when user is admin', :enable_admin_mode do
          let_it_be(:user) { create(:user, :admin, organizations: [current_organization]) }
          let_it_be(:group) { create(:group, organization: current_organization) }
          let_it_be(:project) { create(:project, organization: current_organization, group: group) }

          before do
            sign_in(user)
          end

          context "with occurrences" do
            let_it_be(:per_page) { 20 }
            let_it_be(:occurrences) { create_list(:sbom_occurrence, 2 * per_page, :mit, project: project) }
            let(:cursor) { Sbom::Occurrence.order(:id).keyset_paginate(per_page: per_page).cursor_for_next_page }

            it 'renders a JSON response', :aggregate_failures do
              get explore_dependencies_path(cursor: cursor), as: :json

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to include_keyset_url_params
              expect(response).to include_limited_pagination_headers

              expect(response.headers['X-Page-Type']).to eql('cursor')
              expect(response.headers['X-Per-Page']).to eql(per_page)

              expected_occurrences = occurrences[per_page...(per_page + per_page)].map do |occurrence|
                {
                  'name' => occurrence.name,
                  'packager' => occurrence.packager,
                  'version' => occurrence.version,
                  'location' => occurrence.location.as_json,
                  'occurrence_id' => occurrence.id,
                  'vulnerability_count' => occurrence.vulnerability_count
                }
              end
              expect(json_response["dependencies"]).to match_array(expected_occurrences)
            end
          end

          xit 'avoids N+1 database queries' do # rubocop:disable RSpec/PendingWithoutReason -- TODO: Sbom::Occurrence#has_dependency_paths? has an n+1 query which is unavoidable for now
            get explore_dependencies_path, as: :json # warmup

            create(:sbom_occurrence, project: project)

            control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
              get explore_dependencies_path, as: :json
            end

            create_list(:project, 3, organization: current_organization).each do |project|
              create(:sbom_occurrence, project: project)
            end

            expect do
              get explore_dependencies_path, as: :json
            end.not_to exceed_query_limit(control)
          end

          include_examples 'returning response status', :ok
        end

        context 'when a user is not logged in' do
          include_examples 'returning response status', :not_found
        end
      end

      context 'when dependency scanning is not available' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        include_examples 'returning response status', :not_found

        context 'when user is admin', :enable_admin_mode do
          let_it_be(:user) { create(:user, :admin, organizations: [current_organization]) }

          before do
            sign_in(user)
          end

          include_examples 'returning response status', :forbidden
        end
      end
    end
  end
end
