# frozen_string_literal: true

module EE
  module Ci
    module Pipeline
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::Gitlab::InternalEventsTracking

      prepended do
        include UsageStatistics

        # Subscriptions to this pipeline
        has_many :downstream_bridges, class_name: '::Ci::Bridge', foreign_key: :upstream_pipeline_id
        has_many :security_scans, class_name: 'Security::Scan', inverse_of: :pipeline
        has_many :security_findings, class_name: 'Security::Finding', through: :security_scans, source: :findings

        has_one :dast_profiles_pipeline, class_name: 'Dast::ProfilesPipeline', foreign_key: :ci_pipeline_id
        has_one :dast_profile, class_name: 'Dast::Profile', through: :dast_profiles_pipeline, disable_joins: true

        has_one :source_project, class_name: 'Ci::Sources::Project', foreign_key: :pipeline_id

        # Legacy way to fetch security reports based on job name. This has been replaced by the reports feature.
        scope :with_legacy_security_reports, -> do
          joins(:downloadable_artifacts).where(ci_builds: { name: %w[sast secret_detection dependency_scanning container_scanning dast] })
        end

        scope :latest_completed_or_manual_pipeline_ids_per_source, ->(sha) do
          complete_or_manual
            .group(:source)
            .select('max(id) as id')
            .for_sha(sha)
        end

        SBOM_REPORT_INGESTION_ERRORS_TTL = 15.days.to_i.freeze
        LATEST_PIPELINES_LIMIT = 1000

        # This structure describes feature levels
        # to access the file types for given reports
        REPORT_LICENSED_FEATURES = {
          codequality: nil,
          sast: %i[sast],
          secret_detection: %i[secret_detection],
          dependency_scanning: %i[dependency_scanning],
          container_scanning: %i[container_scanning],
          cluster_image_scanning: %i[cluster_image_scanning],
          dast: %i[dast],
          performance: %i[merge_request_performance_metrics],
          browser_performance: %i[merge_request_performance_metrics],
          load_performance: %i[merge_request_performance_metrics],
          license_scanning: %i[license_scanning],
          metrics: %i[metrics_reports],
          requirements: %i[requirements],
          requirements_v2: %i[requirements],
          coverage_fuzzing: %i[coverage_fuzzing],
          api_fuzzing: %i[api_fuzzing],
          cyclonedx: %i[dependency_scanning container_scanning]
        }.freeze

        def self.latest_limited_pipeline_ids_per_source(pipelines, sha)
          pipelines_for_sha = pipelines.complete_or_manual.for_sha(sha).order(id: :desc).limit(LATEST_PIPELINES_LIMIT)

          from("(#{pipelines_for_sha.to_sql}) AS recent_pipelines")
            .select('DISTINCT ON (source) id')
            .order('source, id DESC')
        end

        state_machine :status do
          before_transition any => ::Ci::Pipeline.completed_with_manual_statuses do |pipeline|
            ::Ci::CompareSecurityReportsService.set_security_mr_widget_to_polling(pipeline_id: pipeline.id)
          end

          after_transition any => ::Ci::Pipeline.completed_with_manual_statuses do |pipeline|
            pipeline.run_after_commit do
              if pipeline.can_store_security_reports?
                ::Security::StoreScansWorker.perform_async(pipeline.id)
                ::Security::ProcessScanEventsWorker.perform_async(pipeline.id)
              else
                ::Sbom::ScheduleIngestReportsService.new(pipeline).execute
                ::Ci::CompareSecurityReportsService.set_security_mr_widget_to_ready(pipeline_id: pipeline.id)
              end
            end
          end

          after_transition any => ::Ci::Pipeline.completed_with_manual_statuses do |pipeline|
            pipeline.run_after_commit do
              ::Ci::SyncReportsToReportApprovalRulesWorker.perform_async(pipeline.id)
            end
          end

          after_transition any => ::Ci::Pipeline.completed_with_manual_statuses do |pipeline|
            pipeline.run_after_commit do
              ::Security::UnenforceablePolicyRulesPipelineNotificationWorker.perform_async(pipeline.id)
            end
          end

          after_transition any => ::Ci::Pipeline.bridgeable_statuses.map(&:to_sym) do |pipeline|
            next unless pipeline.downstream_bridges.any?

            pipeline.run_after_commit do
              ::Ci::PipelineBridgeStatusWorker.perform_async(pipeline.id)
            end
          end

          after_transition any => ::Ci::Pipeline.completed_statuses do |pipeline|
            next unless pipeline.triggers_subscriptions?

            pipeline.run_after_commit do
              ::Ci::TriggerDownstreamSubscriptionsWorker.perform_async(pipeline.id)
            end
          end

          after_transition any => ::Ci::Pipeline.completed_statuses do |pipeline|
            next unless pipeline.complete_and_has_reports?(::Ci::JobArtifact.repository_xray_reports)

            pipeline.run_after_commit do
              track_internal_event(
                'ci_repository_xray_artifact_created',
                project: pipeline.project,
                user: pipeline.user
              )
            end
          end

          after_transition any => [:success, :failed] do |pipeline|
            pipeline.run_after_commit do
              Security::PipelineAnalyzersStatusUpdateWorker.perform_async(pipeline.id) if pipeline.default_branch?
            end
          end

          after_transition any => :skipped do |pipeline|
            pipeline.run_after_commit do
              if ::Feature.enabled?(:collect_security_policy_skipped_pipelines_audit_events, pipeline.project)
                Security::Policies::SkipPipelinesAuditWorker.perform_async(pipeline.id)
              end
            end
          end
        end
      end

      def needs_touch?
        updated_at < 5.minutes.ago
      end

      def triggers_subscriptions?
        # Currently we trigger subscriptions only for tags.
        tag? && project_has_subscriptions?
      end

      def security_reports(report_types: [])
        reports_scope = report_types.empty? ? ::Ci::JobArtifact.security_reports : ::Ci::JobArtifact.security_reports(file_types: report_types)
        types_to_collect = report_types.empty? ? ::EE::Enums::Ci::JobArtifact.security_report_file_types : report_types

        ::Gitlab::Ci::Reports::Security::Reports.new(self).tap do |security_reports|
          latest_report_builds_in_self_and_project_descendants(reports_scope).includes(pipeline: { project: :route }).find_each do |build|
            build.collect_security_reports!(security_reports, report_types: types_to_collect)
          end
        end
      end

      def batch_lookup_report_artifact_for_file_types(file_types)
        file_types_to_search = []
        file_types.each do |file_type|
          file_types_to_search.append(file_type) if available_licensed_report_type?(file_type)
        end

        return unless file_types_to_search.present?

        super(file_types_to_search)
      end

      def metrics_report
        if ::Feature.enabled?(:show_child_reports_in_mr_page, project)
          ::Gitlab::Ci::Reports::Metrics::Report.new.tap do |metrics_report|
            latest_report_builds_in_self_and_project_descendants(::Ci::JobArtifact.of_report_type(:metrics)).each do |build|
              build.collect_metrics_reports!(metrics_report)
            end
          end
        else
          ::Gitlab::Ci::Reports::Metrics::Report.new.tap do |metrics_report|
            latest_report_builds(::Ci::JobArtifact.of_report_type(:metrics)).each do |build|
              build.collect_metrics_reports!(metrics_report)
            end
          end
        end
      end

      def sbom_reports(self_and_project_descendants: false)
        report_builds = if self_and_project_descendants
                          method(:latest_report_builds_in_self_and_project_descendants)
                        else
                          method(:latest_report_builds)
                        end

        ::Gitlab::Ci::Reports::Sbom::Reports.new.tap do |sbom_reports|
          report_builds.call(::Ci::JobArtifact.of_report_type(:sbom)).each do |build|
            build.collect_sbom_reports!(sbom_reports)
          end
        end
      end

      ##
      # Check if it's a merge request pipeline with the HEAD of source and target branches
      # TODO: Make `Ci::Pipeline#latest?` compatible with merge request pipelines and remove this method.
      def latest_merged_result_pipeline?
        merged_result_pipeline? &&
          source_sha == merge_request.diff_head_sha &&
          target_sha == merge_request.target_branch_sha
      end

      override :merge_request_event_type
      def merge_request_event_type
        return unless merge_request?

        strong_memoize(:merge_request_event_type) do
          merge_train_pipeline? ? :merge_train : super
        end
      end

      override :retryable?
      def retryable?
        # if a merge train pipeline is complete, retrying jobs won't put it the MR back
        # in the train, this prevents users from uselessly retrying the pipeline.
        return false if merge_train_pipeline? && complete?

        super
      end

      override :merge_train_pipeline?
      def merge_train_pipeline?
        merged_result_pipeline? && merge_train_ref?
      end

      def latest_failed_security_builds
        security_builds.select(&:latest?)
                       .select(&:failed?)
      end

      def license_scan_completed?
        latest_report_builds(::Ci::JobArtifact.of_report_type(:license_scanning)).exists?
      end

      def can_ingest_sbom_reports?
        project.namespace.ingest_sbom_reports_available? && has_sbom_reports?
      end

      def has_sbom_reports?
        complete_or_manual_and_has_reports?(::Ci::JobArtifact.of_report_type(:sbom))
      end

      def has_dependency_scanning_reports?
        complete_or_manual_and_has_reports?(::Ci::JobArtifact.of_report_type(:dependency_list))
      end

      def can_store_security_reports?
        project.can_store_security_reports? && has_security_reports?
      end

      # We want all the `security_findings` records for a particular pipeline to be stored in
      # the same partition, therefore, we check if the pipeline already has a `security_scan`.
      #
      # - If it has, then we use the partition number of the existing security_scan to make sure
      # that the new `security_findings` will be stored in the same partition with the existing ones.
      # - If it does not have a security_scan yet, then we can basically use the latest partition
      # of the `security_findings` table.
      def security_findings_partition_number
        @security_findings_partition_number ||= security_scans.first&.findings_partition_number || Security::Finding.active_partition_number
      end

      def has_security_findings_in_self_and_descendants?
        Security::Finding.by_project_id_and_pipeline_ids(project_id, self_and_project_descendants.pluck(:id)).exists?
      end

      def triggered_for_ondemand_dast_scan?
        ondemand_dast_scan? && parameter_source?
      end

      def has_security_report_ingestion_warnings?
        security_scans.with_warnings.exists?
      end

      def has_security_report_ingestion_errors?
        security_scans.with_errors.exists?
      end

      def has_sbom_report_ingestion_errors?
        sbom_report_ingestion_errors.present?
      end

      def set_sbom_report_ingestion_errors(sbom_errors)
        # Ensure error messages are kept under a manageable size
        value = sbom_errors.first(10).map { |e| [e.first.truncate(255)] }.to_json
        ::Gitlab::Redis::SharedState.with { |redis| redis.set(sbom_report_ingestion_errors_redis_key, value, ex: SBOM_REPORT_INGESTION_ERRORS_TTL) }
      end

      def sbom_report_ingestion_errors
        ::Gitlab::Redis::SharedState.with { |redis| redis.get(sbom_report_ingestion_errors_redis_key) }
                                    .then { |sbom_errors| ::Gitlab::Json.parse(sbom_errors) if sbom_errors }
      end

      def total_ci_minutes_consumed
        ::Gitlab::Ci::Minutes::PipelineConsumption.new(self).amount
      end

      def security_scan_types
        security_scans.pluck(:scan_type)
      end

      def self_and_descendant_security_scans
        Security::Scan.where(pipeline_id: self_and_project_descendants.pluck(:id))
      end

      def has_security_reports?
        security_and_license_scanning_file_types = EE::Enums::Ci::JobArtifact.security_report_and_cyclonedx_report_file_types | %w[license_scanning]

        complete_or_manual_and_has_reports?(::Ci::JobArtifact.with_file_types(security_and_license_scanning_file_types))
      end

      def has_all_security_policies_reports?
        can_store_security_reports? && can_ingest_sbom_reports?
      end

      # All opened merge requests for which the current pipeline that runs/ran for the head commit
      def opened_merge_requests_with_head_sha
        all_merge_requests.opened.select { |merge_request| merge_request.diff_head_pipeline?(self) }
      end

      def merge_requests_as_base_pipeline
        merge_request_diffs = ::MergeRequestDiff.where(project_id: project_id, base_commit_sha: sha).regular
        project.merge_requests.opened.by_latest_merge_request_diffs(merge_request_diffs)
      end

      private

      def project_has_subscriptions?
        project.feature_available?(:ci_project_subscriptions) &&
          project.downstream_project_subscriptions.any?
      end

      def merge_train_ref?
        ::MergeRequest.merge_train_ref?(ref)
      end

      def available_licensed_report_type?(file_type)
        feature_names = REPORT_LICENSED_FEATURES.fetch(file_type)
        feature_names.nil? || feature_names.any? { |feature| project.feature_available?(feature) }
      end

      def security_builds
        @security_builds ||= ::Security::SecurityJobsFinder.new(pipeline: self).execute
      end

      def sbom_report_ingestion_errors_redis_key
        "sbom_report_ingestion_errors/#{id}"
      end
    end
  end
end
