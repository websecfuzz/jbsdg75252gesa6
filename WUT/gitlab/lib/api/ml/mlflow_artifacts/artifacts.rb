# frozen_string_literal: true

require 'mime/types'

module API
  # MLFlow integration API, replicating the Rest API https://www.mlflow.org/docs/latest/rest-api.html#rest-api
  module Ml
    module MlflowArtifacts
      CANDIDATE_PREFIX = 'candidate:'

      class Artifacts < ::API::Base
        feature_category :mlops
        helpers ::API::Helpers::PackagesHelpers

        before do
          check_api_read!
          check_api_model_registry_read!
        end

        desc 'MLflow artifact API' do
          detail 'MLflow artifacts mapping to GitLab artifacts'
        end

        route_setting :api, write: true
        route_setting :model_registry, write: true
        params do
          optional :path, type: String,
            desc: 'Path to the artifact, model version id, optionally followed by path. E.g. 15/MLmodel'
        end
        get 'artifacts', urgency: :low do
          model_version, path = params[:path].split('/', 2)

          # MLflow handles directories differently than GitLab does so when MLflow checks if a path is a directory
          # we return an empty array as 404s would cause issues for MLflow
          files = if candidate_version?(model_version)
                    run_version = model_version.delete_prefix(CANDIDATE_PREFIX)
                    path.present? ? [] : list_run_artifacts(user_project, run_version).all
                  else
                    path.present? ? [] : list_model_artifacts(user_project, model_version).all
                  end

          package_files = { files: files }
          present package_files, with: Entities::Ml::MlflowArtifacts::ArtifactsList
        end

        get 'artifacts/:model_version/*file_path', format: false, urgency: :low do
          if candidate_version?(params[:model_version])
            version = params[:model_version].delete_prefix(CANDIDATE_PREFIX)
            present_package_file!(find_run_artifact(user_project, version, CGI.escape(params[:file_path])))
          else
            present_package_file!(find_model_artifact(user_project, params[:model_version],
              CGI.escape(params[:file_path])))
          end
        end
      end
    end
  end
end
