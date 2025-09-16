# frozen_string_literal: true

module EE
  module Projects
    module PipelineHelper
      extend ::Gitlab::Utils::Override

      override :js_pipeline_tabs_data
      def js_pipeline_tabs_data(project, pipeline, user)
        super.merge(
          can_generate_codequality_reports: pipeline.can_generate_codequality_reports?.to_json,
          can_manage_licenses: user&.can?(:admin_software_license_policy, project).to_s,
          codequality_report_download_path: codequality_report_download_path(project, pipeline),
          codequality_blob_path: codequality_blob_path(project, pipeline),
          codequality_project_path: codequality_project_path(project, pipeline),
          expose_license_scanning_data: expose_license_scanning_data?(project, pipeline).to_json,
          expose_security_dashboard: pipeline.expose_security_dashboard?.to_json,
          is_full_codequality_report_available: project.licensed_feature_available?(:full_codequality_report).to_json,
          license_management_api_url: license_management_api_url(project),
          licenses_api_path: licenses_api_path(project, pipeline),
          security_policies_path: security_policies_path(project),
          vulnerability_report_data: vulnerability_report_data(project, pipeline, user).to_json,
          dismissal_descriptions: dismissal_descriptions.to_json,
          sbom_reports_errors: sbom_reports_errors(pipeline).to_json
        )
      end

      override :js_pipeline_header_data
      def js_pipeline_header_data(project, pipeline)
        super.merge(
          identity_verification_required: identity_verification_required?(pipeline).to_s,
          identity_verification_path: identity_verification_path,
          merge_trains_available: project.licensed_feature_available?(:merge_trains).to_s,
          can_read_merge_train: can?(current_user, :read_merge_train, project).to_s,
          merge_trains_path: project_merge_trains_path(project)
        )
      end

      def licenses_api_path(project, pipeline)
        if project.licensed_feature_available?(:license_scanning)
          licenses_project_pipeline_path(project, pipeline)
        end
      end

      def expose_license_scanning_data?(project, pipeline)
        project.licensed_feature_available?(:license_scanning) && scanner_for_pipeline(project, pipeline).has_data?
      end

      def codequality_blob_path(project, pipeline)
        return unless project.licensed_feature_available?(:full_codequality_report)

        project_blob_path(project, pipeline)
      end

      def codequality_project_path(project, pipeline)
        return unless project.licensed_feature_available?(:full_codequality_report)

        project_path(project, pipeline)
      end

      def codequality_report_download_path(project, pipeline)
        return unless project.licensed_feature_available?(:full_codequality_report)

        pipeline.downloadable_path_for_report_type(:codequality)
      end

      def vulnerability_report_data(project, pipeline, user)
        ::Security::VulnerabilityReportDataSerializer.new.represent(pipeline, project: project, user: user)
      end

      private

      def scanner_for_pipeline(project, pipeline)
        @scanner_for_pipeline ||= ::Gitlab::LicenseScanning.scanner_for_pipeline(project, pipeline)
      end

      def identity_verification_required?(pipeline)
        user = pipeline.user

        return false unless user
        return false if current_user != user

        user_can_run_pipelines = ::Users::IdentityVerification::AuthorizeCi.new(
          user: current_user, project: pipeline.project
        ).user_can_run_jobs?

        pipeline.user_not_verified? && !user_can_run_pipelines
      end

      def sbom_reports_errors(pipeline)
        pipeline.sbom_report_ingestion_errors || []
      end
    end
  end
end
