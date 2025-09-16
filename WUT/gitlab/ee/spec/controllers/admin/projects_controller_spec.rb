# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ProjectsController, :geo, feature_category: :groups_and_projects do
  let_it_be(:admin) { create(:admin) }

  describe 'GET /projects/:id' do
    let_it_be(:project) { create(:project) }

    subject { get :show, params: { namespace_id: project.namespace.path, id: project.path } }

    render_views

    context 'for Geo' do
      include EE::GeoHelpers

      let_it_be(:primary) { create(:geo_node, :primary) }
      let_it_be(:secondary) { create(:geo_node, :secondary) }

      before do
        sign_in(admin)
      end

      context 'when Geo is enabled' do
        context 'on a primary site' do
          before do
            stub_current_geo_node(primary)
          end

          it 'does not display a different read-only message' do
            expect(subject).to have_gitlab_http_status(:ok)

            expect(subject.body).not_to match('You may be able to make a limited amount of changes or perform a limited amount of actions on this page')
            expect(subject.body).not_to include(primary.url)
          end
        end

        context 'on a secondary site' do
          before do
            stub_current_geo_node(secondary)
          end

          it 'displays a different read-only message based on skip_readonly_message' do
            expect(subject.body).to match('You may be able to make a limited amount of changes or perform a limited amount of actions on this page')
            expect(subject.body).to include(primary.url)
          end
        end
      end

      context 'without Geo enabled' do
        it 'does not display a different read-only message' do
          expect(subject).to have_gitlab_http_status(:ok)

          expect(subject.body).not_to match('You may be able to make a limited amount of changes or perform a limited amount of actions on this page')
          expect(subject.body).not_to include(primary.url)
        end
      end
    end
  end
end
