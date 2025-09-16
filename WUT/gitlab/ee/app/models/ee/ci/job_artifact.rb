# frozen_string_literal: true

module EE
  # CI::JobArtifact EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `Ci::JobArtifact` model
  module Ci::JobArtifact
    include ::Gitlab::Utils::StrongMemoize
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include ::Geo::ReplicableModel
      include ::Geo::VerifiableModel
      include ::Geo::ReplicableCiArtifactable

      delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :job_artifact_state)

      with_replicator ::Geo::JobArtifactReplicator

      has_one :job_artifact_state,
        ->(artifact) { in_partition(artifact) },
        autosave: false,
        inverse_of: :job_artifact,
        partition_foreign_key: :partition_id,
        class_name: '::Geo::JobArtifactState'

      EE_REPORT_FILE_TYPES = EE::Enums::Ci::JobArtifact.ee_report_file_types

      scope :security_reports, ->(file_types: EE::Enums::Ci::JobArtifact.security_report_and_cyclonedx_report_file_types) do
        requested_file_types = *file_types
        valid_file_types = requested_file_types & EE::Enums::Ci::JobArtifact.security_report_and_cyclonedx_report_file_types

        with_file_types(valid_file_types)
      end

      scope :with_verification_state, ->(state) { joins(:job_artifact_state).where(verification_arel_table[:verification_state].eq(verification_state_value(state))) }
      scope :checksummed, -> { joins(:job_artifact_state).where.not(verification_arel_table[:verification_checksum].eq(nil)) }
      scope :not_checksummed, -> { joins(:job_artifact_state).where(verification_arel_table[:verification_checksum].eq(nil)) }

      scope :available_verifiables, -> { joins(:job_artifact_state) }

      scope :repository_xray_reports, -> { with_file_types(%w[repository_xray]) }

      skip_callback :commit, :after, :geo_create_event!, if: :store_after_commit?
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      # Search for a list of projects associated, based on the query given in `query`.
      #
      # @param [String] query term that will search over projects :path, :name and :description
      #
      # @return [ActiveRecord::Relation<Ci::JobArtifact>] a collection of job artifacts
      def search(query)
        return all if query.empty?

        # This is divided into two separate queries, one for the CI and one for the main database
        for_project(::Project.search(query).limit(1000).pluck_primary_key)
      end

      override :associated_file_types_for
      def associated_file_types_for(file_type)
        return file_types_for_report(:license_scanning) if file_types_for_report(:license_scanning).include?(file_type)
        return file_types_for_report(:browser_performance) if file_types_for_report(:browser_performance).include?(file_type)

        super
      end

      override :verification_state_table_class
      def verification_state_table_class
        ::Geo::JobArtifactState
      end

      override :file_types_for_report
      def file_types_for_report(report_type)
        EE_REPORT_FILE_TYPES.fetch(report_type) { super }
      end

      override :create_verification_details_for
      def create_verification_details_for(primary_keys)
        job_artifacts = find(primary_keys)

        rows = job_artifacts.map do |artifact|
          { verification_state_model_key => artifact.id, :partition_id => artifact.partition_id }
        end

        verification_state_table_class.insert_all(rows)
      end
    end

    override :file_stored_after_transaction_hooks
    def file_stored_after_transaction_hooks
      super

      is_being_created = previous_changes.key?(:id) && previous_changes[:id].first.nil?

      geo_create_event! if is_being_created

      save_verification_details
    end

    override :file_stored_in_transaction_hooks
    def file_stored_in_transaction_hooks
      super

      save_verification_details
    end

    def job_artifact_state
      super || build_job_artifact_state
    end

    def verification_state_object
      job_artifact_state
    end

    # Ideally we would have a method to return an instance of
    # parsed report regardless of the `file_type` but this will
    # require more effort so we can have this security reports
    # specific method here for now.
    def security_report(validate: false)
      strong_memoize(:security_report) do
        next unless file_type.in?(EE::Enums::Ci::JobArtifact.security_report_and_cyclonedx_report_file_types)

        signatures_enabled = project.licensed_feature_available?(:vulnerability_finding_signatures)

        report = build_security_report(signatures_enabled: signatures_enabled, validate: validate)

        next unless report.present?

        # This will remove the duplicated findings within the artifact itself
        ::Security::MergeReportsService.new(report).execute
      end
    end

    def build_security_report(signatures_enabled:, validate:)
      if file_type == 'cyclonedx'
        sbom_reports = parse_sbom_reports
        return ::Gitlab::VulnerabilityScanning::SecurityReportBuilder.new(
          sbom_reports: sbom_reports, project: project, pipeline: job.pipeline).execute
      end

      parse_security_report(signatures_enabled: signatures_enabled, validate: validate)
    end

    def parse_sbom_reports
      ::Gitlab::Ci::Reports::Sbom::Reports.new.tap do |sbom_reports|
        each_blob do |blob|
          ::Gitlab::Ci::Reports::Sbom::Report.new.tap do |report|
            ::Gitlab::Ci::Parsers.fabricate!(file_type).parse!(blob, report)
            sbom_reports.add_report(report)
          end
        end
      end
    end

    def parse_security_report(signatures_enabled:, validate:)
      base_security_report.tap do |report|
        each_blob do |blob|
          ::Gitlab::Ci::Parsers.fabricate!(file_type, blob, report, signatures_enabled: signatures_enabled, validate: validate).parse!
        rescue StandardError
          report.add_error('ParsingError')
        end
      end
    end

    def base_security_report
      ::Gitlab::Ci::Reports::Security::Report.new(file_type, job.pipeline, nil)
    end

    # This method is necessary to remove the reference to the
    # security report object which allows GC to free the memory
    # slots in vm_heap occupied for the report object and it's
    # dependents.
    def clear_security_report
      clear_memoization(:security_report)
    end
  end
end
