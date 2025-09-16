# frozen_string_literal: true

module API
  class ProjectSnippets < ::API::Base
    include PaginationParams

    before do
      check_snippets_enabled
      set_current_organization
    end

    feature_category :source_code_management

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      helpers Helpers::SnippetsHelpers
      helpers SpammableActions::CaptchaCheck::RestApiActionsSupport
      helpers do
        def check_snippets_enabled
          forbidden! unless user_project.feature_available?(:snippets, current_user)
        end

        def handle_project_member_errors(errors)
          if errors[:project_access].any?
            error!(errors[:project_access], 422)
          end

          not_found!
        end

        def snippets_for_current_user
          SnippetsFinder.new(current_user, project: user_project).execute
        end
      end

      desc 'Get all project snippets' do
        success Entities::ProjectSnippet
        failure [
          { code: 404, message: 'Not found' }
        ]
        tags %w[project_snippets]
        is_array true
      end
      params do
        use :pagination
      end
      get ":id/snippets", urgency: :low do
        authenticate!

        present paginate(snippets_for_current_user), with: Entities::ProjectSnippet, current_user: current_user
      end

      desc 'Get a single project snippet' do
        success Entities::ProjectSnippet
        failure [
          { code: 404, message: 'Not found' }
        ]
        tags %w[project_snippets]
      end
      params do
        requires :snippet_id, type: Integer, desc: 'The ID of a project snippet'
      end
      get ":id/snippets/:snippet_id" do
        snippet = snippets_for_current_user.find(params[:snippet_id])

        not_found!('Snippet') unless snippet

        present snippet, with: Entities::ProjectSnippet, current_user: current_user
      end

      desc 'Create a new project snippet' do
        success Entities::ProjectSnippet
        failure [
          { code: 400, message: 'Validation error' },
          { code: 404, message: 'Not found' },
          { code: 422, message: 'Unprocessable entity' }
        ]
        tags %w[project_snippets]
      end
      params do
        requires :title, type: String, allow_blank: false, desc: 'The title of the snippet'
        optional :description, type: String, desc: 'The description of a snippet'
        requires :visibility, type: String,
          values: Gitlab::VisibilityLevel.string_values,
          desc: 'The visibility of the snippet'
        use :create_file_params
      end
      post ":id/snippets" do
        authenticate!

        authorize! :create_snippet, user_project

        snippet_params = process_create_params(declared_params(include_missing: false))
        service_response = ::Snippets::CreateService.new(project: user_project, current_user: current_user, params: snippet_params).execute
        snippet = service_response.payload[:snippet]

        if service_response.success?
          present snippet, with: Entities::ProjectSnippet, current_user: current_user
        else
          with_captcha_check_rest_api(spammable: snippet) do
            http_status = Helpers::Snippets::HttpResponseMap.status_for(service_response.reason)
            render_api_error!({ error: service_response.message }, http_status)
          end
        end
      end

      desc 'Update an existing project snippet' do
        success Entities::ProjectSnippet
        failure [
          { code: 400, message: 'Validation error' },
          { code: 404, message: 'Not found' },
          { code: 422, message: 'Unprocessable entity' }
        ]
        tags %w[project_snippets]
      end
      params do
        requires :snippet_id, type: Integer, desc: 'The ID of a project snippet'
        optional :content, type: String, allow_blank: false, desc: 'The content of the snippet'
        optional :description, type: String, desc: 'The description of a snippet'
        optional :file_name, type: String, desc: 'The file name of the snippet'
        optional :title, type: String, allow_blank: false, desc: 'The title of the snippet'
        optional :visibility, type: String,
          values: Gitlab::VisibilityLevel.string_values,
          desc: 'The visibility of the snippet'

        use :update_file_params
        use :minimum_update_params
      end
      # rubocop: disable CodeReuse/ActiveRecord
      put ":id/snippets/:snippet_id" do
        authenticate!

        snippet = snippets_for_current_user.find_by(id: params.delete(:snippet_id))
        not_found!('Snippet') unless snippet

        authorize! :update_snippet, snippet

        validate_params_for_multiple_files(snippet)

        snippet_params = process_update_params(declared_params(include_missing: false))
        service_response = ::Snippets::UpdateService.new(project: user_project, current_user: current_user, params: snippet_params, perform_spam_check: true).execute(snippet)
        snippet = service_response.payload[:snippet]

        if service_response.success?
          present snippet, with: Entities::ProjectSnippet, current_user: current_user
        else
          with_captcha_check_rest_api(spammable: snippet) do
            http_status = Helpers::Snippets::HttpResponseMap.status_for(service_response.reason)
            render_api_error!({ error: service_response.message }, http_status)
          end
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Delete a project snippet' do
        success code: 204
        failure [
          { code: 400, message: 'Validation error' },
          { code: 404, message: 'Not found' }
        ]
        tags %w[project_snippets]
      end
      params do
        requires :snippet_id, type: Integer, desc: 'The ID of a project snippet'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      delete ":id/snippets/:snippet_id" do
        authenticate!

        snippet = snippets_for_current_user.find_by(id: params[:snippet_id])
        not_found!('Snippet') unless snippet

        authorize! :admin_snippet, snippet

        destroy_conditionally!(snippet) do |snippet|
          service = ::Snippets::DestroyService.new(current_user, snippet)
          response = service.execute
          http_status = Helpers::Snippets::HttpResponseMap.status_for(response.reason)

          if response.error?
            render_api_error!({ error: response.message }, http_status)
          end
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Get a raw project snippet' do
        success Entities::ProjectSnippet
        failure [
          { code: 404, message: 'Not found' }
        ]
        tags %w[project_snippets]
      end
      params do
        requires :snippet_id, type: Integer, desc: 'The ID of a project snippet'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      get ":id/snippets/:snippet_id/raw" do
        snippet = snippets_for_current_user.find_by(id: params[:snippet_id])
        not_found!('Snippet') unless snippet

        present content_for(snippet)
      end

      desc 'Get raw project snippet file contents from the repository' do
        success Entities::ProjectSnippet
        failure [
          { code: 404, message: 'Not found' }
        ]
        tags %w[project_snippets]
      end
      params do
        use :raw_file_params
      end
      get ":id/snippets/:snippet_id/files/:ref/:file_path/raw", requirements: { file_path: API::NO_SLASH_URL_PART_REGEX } do
        snippet = snippets_for_current_user.find_by(id: params[:snippet_id])
        not_found!('Snippet') unless snippet&.repo_exists?

        present file_content_for(snippet)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Get the user agent details for a project snippet' do
        success Entities::UserAgentDetail
        failure [
          { code: 404, message: 'Not found' }
        ]
        tags %w[project_snippets]
      end
      params do
        requires :snippet_id, type: Integer, desc: 'The ID of a project snippet'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      get ":id/snippets/:snippet_id/user_agent_detail" do
        authenticated_as_admin!

        snippet = Snippet.find_by!(id: params[:snippet_id], project_id: params[:id])

        break not_found!('UserAgentDetail') unless snippet.user_agent_detail

        present snippet.user_agent_detail, with: Entities::UserAgentDetail
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
