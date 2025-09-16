# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::IngestReportsService, feature_category: :vulnerability_management do
  let(:service_object) { described_class.new(pipeline) }

  let_it_be_with_refind(:project) { create(:project) }
  let_it_be_with_refind(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:build) { create(:ci_build, pipeline: pipeline) }
  let_it_be(:security_scan_1) { create(:security_scan, build: build, scan_type: :sast) }
  let_it_be(:security_scan_2) { create(:security_scan, :with_error, build: build, scan_type: :dast) }
  let_it_be(:security_scan_3) { create(:security_scan, build: build, scan_type: :dependency_scanning) }
  let_it_be(:vulnerability_1) { create(:vulnerability, project: pipeline.project) }
  let_it_be(:vulnerability_2) { create(:vulnerability, project: pipeline.project) }
  let_it_be(:sast_scanner) { create(:vulnerabilities_scanner, project: project, external_id: 'find_sec_bugs') }
  let_it_be(:gemnasium_scanner) { create(:vulnerabilities_scanner, project: project, external_id: 'gemnasium-maven') }
  let_it_be(:sast_artifact) { create(:ee_ci_job_artifact, :sast, job: build, project: project) }
  let!(:dependency_scanning_artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: build, project: project) }

  describe '#execute' do
    let(:ids_1) { [vulnerability_1.id] }
    let(:ids_2) { [] }

    subject(:ingest_reports) { service_object.execute }

    before do
      allow(Security::Ingestion::IngestReportService).to receive(:execute).and_return(ids_1, ids_2)
      allow(Security::Ingestion::ScheduleMarkDroppedAsResolvedService).to receive(:execute)
      allow(Sbom::IngestReportsWorker).to receive(:perform_async)
    end

    it 'calls IngestReportService for each succeeded security scan', :aggregate_failures do
      ingest_reports

      expect(Security::Ingestion::IngestReportService).to have_received(:execute).twice
      expect(Security::Ingestion::IngestReportService).to have_received(:execute).once.with(security_scan_1)
      expect(Security::Ingestion::IngestReportService).to have_received(:execute).once.with(security_scan_3)
    end

    it_behaves_like 'schedules synchronization of vulnerability statistic' do
      let(:latest_pipeline) { pipeline }
    end

    context 'when ingested reports are empty' do
      let(:ids_1) { [] }
      let(:ids_2) { [] }

      it 'does not set has_vulnerabilities' do
        expect { ingest_reports }.not_to change { project.reload.project_setting.has_vulnerabilities }.from(false)
      end
    end

    it 'calls ScheduleMarkDroppedAsResolvedService with primary identifier IDs' do
      ingest_reports

      expect(
        Security::Ingestion::ScheduleMarkDroppedAsResolvedService
      ).to have_received(:execute).with(project.id, 'sast', sast_artifact.security_report.primary_identifiers)
    end

    it 'marks vulnerabilities as resolved' do
      expect(Security::Ingestion::MarkAsResolvedService).to receive(:execute).once.with(pipeline, sast_scanner, ids_1)
      expect(Security::Ingestion::MarkAsResolvedService).to receive(:execute).once.with(pipeline, gemnasium_scanner, [])
      ingest_reports
    end

    context 'when the same scanner is used into separate child pipelines' do
      let_it_be(:parent_pipeline) { create(:ee_ci_pipeline, :success, project: project) }
      let_it_be(:child_pipeline_1) { create(:ee_ci_pipeline, :success, child_of: parent_pipeline, project: project) }
      let_it_be(:child_pipeline_2) { create(:ee_ci_pipeline, :success, child_of: parent_pipeline, project: project) }
      let_it_be(:parent_scan) { create(:security_scan, pipeline: parent_pipeline, scan_type: :sast) }
      let_it_be(:scan_1) { create(:security_scan, pipeline: child_pipeline_1, project: project, scan_type: :sast) }
      let_it_be(:scan_2) { create(:security_scan, pipeline: child_pipeline_2, project: project, scan_type: :sast) }
      let_it_be(:artifact_sast_1) { create(:ee_ci_job_artifact, :sast, job: scan_1.build, project: project) }
      let_it_be(:artifact_sast_2) { create(:ee_ci_job_artifact, :sast, job: scan_2.build, project: project) }

      subject(:service_object) { described_class.new(parent_pipeline) }

      it 'ingests the scan from both child pipelines' do
        service_object.execute

        expect(Security::Ingestion::IngestReportService).not_to have_received(:execute).with(parent_scan)
        expect(Security::Ingestion::IngestReportService).to have_received(:execute).with(scan_1)
        expect(Security::Ingestion::IngestReportService).to have_received(:execute).with(scan_2)
      end
    end

    it_behaves_like 'schedules synchronization of findings to approval rules' do
      let(:latest_pipeline) { pipeline }
    end

    context 'when scheduling the SBOM ingestion' do
      let(:sbom_ingestion_scheduler) { instance_double(::Sbom::ScheduleIngestReportsService, execute: nil) }

      before do
        allow(::Sbom::ScheduleIngestReportsService).to receive(:new).with(pipeline).and_return(sbom_ingestion_scheduler)
      end

      it 'defers to ScheduleIngestReportsService' do
        ingest_reports

        expect(::Sbom::ScheduleIngestReportsService).to have_received(:new).with(pipeline)
        expect(sbom_ingestion_scheduler).to have_received(:execute)
      end
    end

    it_behaves_like 'rescheduling archival status and traversal_ids update jobs' do
      let(:job_args) { project.id }
      let(:scheduling_method) { :perform_async }
      let(:ingest_vulnerabilities) { ingest_reports }
      let(:update_archived_after_start) do
        allow(service_object).to receive(:store_reports).and_wrap_original do |method|
          project.update_column(:archived, true)

          method.call
        end
      end

      let(:update_traversal_ids_after_start) do
        allow(service_object).to receive(:store_reports).and_wrap_original do |method|
          project.namespace.update_column(:traversal_ids, [-1])

          method.call
        end
      end

      let(:update_namespace_after_start) do
        allow(service_object).to receive(:store_reports).and_wrap_original do |method|
          project.update_column(:namespace_id, new_namespace.id)

          method.call
        end
      end
    end
  end
end
