# frozen_string_literal: true

module API
  class ProjectGoogleCloudIntegration < ::API::Base
    feature_category :integrations

    include GrapePathHelpers::NamedRouteMatcher

    GOOGLE_PROJECT_ID_REGEXP = /\A[a-z][a-z0-9-]{5,28}[a-z0-9]\z/

    before { authorize_admin_project }
    before do
      not_found! unless ::Gitlab::Saas.feature_available?(:google_cloud_support)
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      namespace ':id/google_cloud/setup' do
        desc 'Get shell script to setup an integration in Google Cloud' do
          detail 'This feature is experimental.'
        end
        params do
          optional :enable_google_cloud_artifact_registry, types: Boolean
          optional :google_cloud_artifact_registry_project_id, types: String, regexp: GOOGLE_PROJECT_ID_REGEXP
          at_least_one_of :enable_google_cloud_artifact_registry
        end
        get '/integrations.sh' do
          env['api.format'] = :binary
          content_type 'text/plain'

          wlif_integration = user_project.google_cloud_platform_workload_identity_federation_integration
          unless ::Gitlab::Saas.feature_available?(:google_cloud_support) && wlif_integration&.activated?
            render_api_error!('Workload Identity Federation is not configured', 400)
          end

          template_path = File.join(
            'ee', 'lib', 'api', 'templates', 'google_cloud_integration_setup_integration.sh.erb')
          template = ERB.new(File.read(template_path))

          locals = {
            google_cloud_artifact_registry_project_id:
              declared_params[:google_cloud_artifact_registry_project_id],
            identity_provider: wlif_integration.identity_pool_resource_name,
            oidc_claim_grants: [
              { claim_name: 'reporter_access', claim_value: 'true', iam_role: 'roles/artifactregistry.reader' },
              { claim_name: 'developer_access', claim_value: 'true', iam_role: 'roles/artifactregistry.writer' }
            ],
            api_integrations_url:
              Gitlab::Utils.append_path(
                Gitlab.config.gitlab.url,
                api_v4_projects_integrations_path(id: params[:id])
              )
          }

          template.result_with_hash(locals)
        end

        desc 'Get shell script to set up Google Cloud project for runner deployment' do
          detail 'This feature is experimental.'
        end
        params do
          requires :google_cloud_project_id, types: String, regexp: GOOGLE_PROJECT_ID_REGEXP
        end
        get '/runner_deployment_project.sh' do
          env['api.format'] = :binary
          content_type 'text/plain'

          template_path = File.join(
            'ee', 'lib', 'api', 'templates', 'google_cloud_integration_runner_project_setup.sh.erb')
          template = ERB.new(File.read(template_path))

          locals = {
            google_cloud_project_id: declared_params[:google_cloud_project_id]
          }

          template.result_with_hash(locals)
        end
      end
    end
  end
end
