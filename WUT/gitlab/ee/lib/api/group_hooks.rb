# frozen_string_literal: true

module API
  class GroupHooks < ::API::Base
    include ::API::PaginationParams

    group_hooks_tags = %w[group_hooks]

    feature_category :webhooks
    urgency :low

    before { authenticate! }
    before do
      ability = route.request_method == 'GET' ? :read_web_hook : :admin_web_hook
      authorize! ability, user_group
    end

    helpers ::API::Helpers::WebHooksHelpers

    helpers do
      def hook_scope
        user_group.hooks
      end

      params :group_hook_properties do
        optional :name, type: String, desc: 'Name of the hook'
        optional :description, type: String, desc: 'Description of the hook'
        optional :push_events, type: Boolean, desc: "Trigger hook on push events"
        optional :push_events_branch_filter, type: String, desc: "Respond to push events only on branches that match this filter"
        optional :issues_events, type: Boolean, desc: "Trigger hook on issues events"
        optional :confidential_issues_events, type: Boolean, desc: "Trigger hook on confidential issues events"
        optional :merge_requests_events, type: Boolean, desc: "Trigger hook on merge request events"
        optional :tag_push_events, type: Boolean, desc: "Trigger hook on tag push events"
        optional :note_events, type: Boolean, desc: "Trigger hook on note(comment) events"
        optional :confidential_note_events, type: Boolean, desc: "Trigger hook on confidential note(comment) events"
        optional :job_events, type: Boolean, desc: "Trigger hook on job events"
        optional :pipeline_events, type: Boolean, desc: "Trigger hook on pipeline events"
        optional :project_events, type: Boolean, desc: "Trigger hook on project events"
        optional :wiki_page_events, type: Boolean, desc: "Trigger hook on wiki events"
        optional :deployment_events, type: Boolean, desc: "Trigger hook on deployment events"
        optional :feature_flag_events, type: Boolean, desc: "Trigger hook on feature flag events"
        optional :releases_events, type: Boolean, desc: "Trigger hook on release events"
        optional :subgroup_events, type: Boolean, desc: "Trigger hook on subgroup events"
        optional :emoji_events, type: Boolean, desc: "Trigger hook on emoji events"
        optional :resource_access_token_events, type: Boolean, desc: "Trigger hook on group access token expiry events"
        optional :member_events, type: Boolean, desc: "Trigger hook on member events"
        optional :vulnerability_events, type: Boolean, desc: "Trigger hook on vulnerability events"
        optional :enable_ssl_verification, type: Boolean, desc: "Do SSL verification when triggering the hook"
        optional :token, type: String, desc: "Secret token to validate received payloads; this will not be returned in the response"
        optional :custom_webhook_template, type: String, desc: "Custom template for the request payload"
        optional :branch_filter_strategy, type: String, values: WebHook.branch_filter_strategies.keys,
          desc: "Filter push events by branch. Possible values are `wildcard` (default), `regex`, and `all_branches`"
        use :url_variables
        use :custom_headers
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the group'
    end
    resource :groups, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'List group hooks' do
        detail 'Get a list of group hooks'
        success EE::API::Entities::GroupHook
        is_array true
        tags group_hooks_tags
      end
      params do
        use :pagination
      end
      get ":id/hooks" do
        present paginate(user_group.hooks), with: EE::API::Entities::GroupHook
      end

      desc 'Add group hook' do
        detail 'Adds a hook to a specified group'
        success EE::API::Entities::GroupHook
        failure [
          { code: 400, message: 'Validation error' },
          { code: 404, message: 'Not found' },
          { code: 422, message: 'Unprocessable entity' }
        ]
        tags group_hooks_tags
      end
      params do
        use :requires_url
        use :group_hook_properties
      end
      post ":id/hooks" do
        hook_params = create_hook_params

        result = WebHooks::CreateService.new(current_user).execute(hook_params, hook_scope)

        if result[:status] == :success
          present result[:hook], with: EE::API::Entities::GroupHook
        else
          error!(result.message, result.http_status || 422)
        end
      end

      namespace ":id/hooks/:hook_id/" do
        desc 'Get group hook' do
          detail 'Get a specific hook for a group'
          success EE::API::Entities::GroupHook
          failure [
            { code: 404, message: 'Not found' }
          ]
          tags group_hooks_tags
        end
        params do
          requires :hook_id, type: Integer, desc: 'The ID of a group hook'
        end
        get do
          hook = find_hook

          present hook, with: EE::API::Entities::GroupHook
        end

        desc 'Edit group hook' do
          detail 'Edits a hook for a specified group'
          success EE::API::Entities::GroupHook
          failure [
            { code: 400, message: 'Validation error' },
            { code: 404, message: 'Not found' },
            { code: 422, message: 'Unprocessable entity' }
          ]
          tags group_hooks_tags
        end
        params do
          requires :hook_id, type: Integer, desc: 'The ID of the group hook'
          use :optional_url
          use :group_hook_properties
        end
        put do
          update_hook(entity: EE::API::Entities::GroupHook)
        end

        desc 'Delete group hook' do
          detail 'Removes a hook from a group. This is an idempotent method and can be called multiple times. Either the hook is available or not.'
          success EE::API::Entities::GroupHook
          failure [
            { code: 404, message: 'Not found' }
          ]
          tags group_hooks_tags
        end
        params do
          requires :hook_id, type: Integer, desc: 'The ID of the group hook'
        end
        delete do
          hook = find_hook

          destroy_conditionally!(hook) do
            WebHooks::DestroyService.new(current_user).execute(hook)
          end
        end

        mount ::API::Hooks::Events
      end
      namespace ':id/hooks' do
        mount ::API::Hooks::UrlVariables
        mount ::API::Hooks::CustomHeaders
        mount ::API::Hooks::TriggerTest, with: {
          entity: GroupHook
        }
        mount ::API::Hooks::ResendHook
      end
    end
  end
end
