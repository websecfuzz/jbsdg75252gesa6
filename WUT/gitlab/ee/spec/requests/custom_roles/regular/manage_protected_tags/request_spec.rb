# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with manage_protected_tags custom role', feature_category: :source_code_management do
  include ApiHelpers

  let_it_be(:project) { create(:project, :in_group) }

  let_it_be(:protected_tag) { create(:protected_tag, project: project, name: 'v1.0.0') }

  let_it_be(:user_with_permission) { create(:user) }
  let_it_be(:user_without_permission) { create(:user) }

  let_it_be(:role_with_permission) do
    create(:member_role, :developer, read_code: true, namespace: project.group, manage_protected_tags: true)
  end

  let_it_be(:role_without_permission) do
    create(:member_role, :developer, read_code: true, namespace: project.group, manage_protected_tags: false)
  end

  let_it_be(:member_with_permission) do
    create(:group_member, :developer, member_role: role_with_permission, user: user_with_permission,
      source: project.group)
  end

  let_it_be(:member_without_permission) do
    create(:group_member, :developer, member_role: role_without_permission, user: user_without_permission,
      source: project.group)
  end

  before do
    stub_licensed_features(custom_roles: true)
    stub_feature_flags(custom_ability_manage_protected_tags: true)

    sign_in(user_with_permission)
  end

  describe Projects::Settings::RepositoryController do
    describe 'GET #show' do
      context 'with manage_protected_tags permission' do
        it 'allows user to access project repository settings page' do
          get namespace_project_settings_repository_path(namespace_id: project.namespace, project_id: project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end
  end

  describe API::ProtectedTags do
    describe "GET /projects/:id/protected_tags" do
      context 'with manage_protected_tags permission' do
        it 'returns the list of protected tags' do
          get api("/projects/#{project.id}/protected_tags", user_with_permission)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'without manage_protected_tags permission' do
        it 'returns 403' do
          sign_in(user_without_permission)
          get api("/projects/#{project.id}/protected_tags", user_without_permission)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe "GET /projects/:id/protected_tags/:name" do
    context 'with manage_protected_tags permission' do
      it 'returns the protected tag' do
        get api("/projects/#{project.id}/protected_tags/#{protected_tag.name}", user_with_permission)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['name']).to eq(protected_tag.name)
      end
    end

    context 'without manage_protected_tags permission' do
      it 'returns 403' do
        get api("/projects/#{project.id}/protected_tags/#{protected_tag.name}", user_without_permission)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "POST /projects/:id/protected_tags" do
    let(:params) { { name: 'new-tag', create_access_level: 30 } }

    context 'with manage_protected_tags permission' do
      it 'creates a new protected tag' do
        post api("/projects/#{project.id}/protected_tags", user_with_permission),
          params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['name']).to eq('new-tag')
      end

      it 'responds with 422 if name is missing' do
        post api("/projects/#{project.id}/protected_tags", user_with_permission), params: { create_access_level: 30 }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'responds with 422 if create_access_level is invalid' do
        post api("/projects/#{project.id}/protected_tags", user_with_permission),
          params: { name: 'new-tag', create_access_level: 123 }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'without manage_protected_tags permission' do
      it 'returns 403' do
        post api("/projects/#{project.id}/protected_tags", user_without_permission), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /projects/:id/protected_tags/:name" do
    context 'with manage_protected_tags permission' do
      it 'deletes a protected tag' do
        delete api("/projects/#{project.id}/protected_tags/#{protected_tag.name}", user_with_permission)

        expect(response).to have_gitlab_http_status(:no_content)
        expect { protected_tag.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'without manage_protected_tags permission' do
      it 'returns 403' do
        delete api("/projects/#{project.id}/protected_tags/#{protected_tag.name}", user_without_permission)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
