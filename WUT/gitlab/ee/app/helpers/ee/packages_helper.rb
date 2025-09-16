# frozen_string_literal: true

module EE
  module PackagesHelper
    extend ::Gitlab::Utils::Override

    override :settings_data
    def settings_data(project)
      super.merge(
        show_dependency_proxy_settings: show_dependency_proxy_settings?(project).to_s
      )
    end

    def google_artifact_registry_data(project)
      {
        endpoint: project_google_cloud_artifact_registry_index_path(project),
        full_path: project.full_path,

        settings_path: if show_google_cloud_artifact_registry_settings?(project)
                         edit_project_settings_integration_path(project,
                           ::Integrations::GoogleCloudPlatform::ArtifactRegistry)
                       else
                         ''
                       end
      }
    end

    private

    def show_dependency_proxy_settings?(project)
      Ability.allowed?(
        current_user,
        :admin_dependency_proxy_packages_settings,
        project.dependency_proxy_packages_setting
      )
    end

    def show_google_cloud_artifact_registry_settings?(project)
      ::Gitlab::Saas.feature_available?(:google_cloud_support) &&
        Ability.allowed?(current_user, :admin_google_cloud_artifact_registry, project)
    end
  end
end
