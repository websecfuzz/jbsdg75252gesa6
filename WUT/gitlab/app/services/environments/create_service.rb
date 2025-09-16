# frozen_string_literal: true

module Environments
  class CreateService < BaseService
    ALLOWED_ATTRIBUTES = %i[name description external_url tier cluster_agent kubernetes_namespace
      flux_resource_path auto_stop_setting].freeze

    def execute
      unless can?(current_user, :create_environment, project)
        return ServiceResponse.error(
          message: _('Unauthorized to create an environment'),
          payload: { environment: nil }
        )
      end

      # Note: We skip checking the cluster agent authorization if the `skip_agent_auth`
      # parameter is present. This allows creating environments that reference a cluster agent
      # before the agent has connected for the first time.
      # This is necessary to support the bootstrapping workflow, where environments
      # are created before the agent has connected for the first time.
      # See https://gitlab.com/gitlab-org/cli/-/issues/7786 for context.
      if params[:skip_agent_auth].blank? && unauthorized_cluster_agent?
        return ServiceResponse.error(
          message: _('Unauthorized to access the cluster agent in this project'),
          payload: { environment: nil })
      end

      begin
        environment = project.environments.new(**params.slice(*ALLOWED_ATTRIBUTES))
        environment.ensure_environment_tier
        environment.set_default_auto_stop_setting unless params[:auto_stop_setting]
        environment.save!
        ServiceResponse.success(payload: { environment: environment })
      rescue ActiveRecord::RecordInvalid => err
        ServiceResponse.error(message: err.record.errors.full_messages, payload: { environment: nil })
      rescue ArgumentError => err
        ServiceResponse.error(message: [err.message], payload: { environment: nil })
      end
    end

    private

    def unauthorized_cluster_agent?
      return false unless params[:cluster_agent]

      ::Clusters::Agents::Authorizations::UserAccess::Finder
        .new(current_user, agent: params[:cluster_agent], project: project)
        .execute
        .empty?
    end
  end
end
