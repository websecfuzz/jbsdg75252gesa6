# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreGroupedScansService, feature_category: :vulnerability_management do
  let_it_be(:report_type) { :dast }
  let_it_be(:build_1) { create(:ee_ci_build) }
  let_it_be(:build_2) { create(:ee_ci_build) }
  let_it_be(:build_3) { create(:ee_ci_build) }
  let_it_be(:build_4) { create(:ee_ci_build) }
  let_it_be(:artifact_1) { create(:ee_ci_job_artifact, report_type, job: build_1) }
  let_it_be(:artifact_2) { create(:ee_ci_job_artifact, report_type, job: build_2) }
  let_it_be(:artifact_3) { create(:ee_ci_job_artifact, report_type, job: build_3) }
  let_it_be(:artifact_with_missing_version) { create(:ee_ci_job_artifact, :dast_missing_version, job: build_4) }
  let_it_be(:pipeline) { artifact_1.job.pipeline }
  let_it_be(:pipeline_id) { pipeline.id }

  let(:artifacts) { [artifact_1, artifact_2, artifact_3, artifact_with_missing_version] }
  let(:mock_report) { instance_double(::Gitlab::Ci::Reports::Security::Report, scanner_order_to: -1) }
  let(:failure_mock_report) { instance_double(::Gitlab::Ci::Reports::Security::Report, scanner_order_to: -1) }

  let(:scan_object) do
    ::Gitlab::Ci::Reports::Security::Scan.new(
      {
        "type" => report_type,
        "start_time" => "20241022T11:56:41",
        "end_time" => "20241022T11:57:39",
        "status" => "success"
      })
  end

  let(:failure_scan_object) do
    ::Gitlab::Ci::Reports::Security::Scan.new(
      {
        "type" => report_type,
        "start_time" => "20241022T11:56:41",
        "end_time" => "20241022T11:57:39",
        "status" => "failure"
      })
  end

  before do
    allow(Ci::CompareSecurityReportsService).to receive(:set_security_report_type_to_ready)
  end

  shared_examples_for 'handling the security MR widget caching' do
    it 'sets the expected redis cache value' do
      store_scan_group

      expect(Ci::CompareSecurityReportsService).to have_received(:set_security_report_type_to_ready).with(pipeline_id: pipeline_id, report_type: report_type.to_s)
    end
  end

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute) { described_class.execute(artifacts, pipeline, report_type) }

    before do
      allow(described_class).to receive(:new).with(artifacts, pipeline, report_type).and_return(mock_service_object)
    end

    it 'delegates the call to an instance of `Security::StoreGroupedScansService`' do
      execute

      expect(described_class).to have_received(:new).with(artifacts, pipeline, report_type)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:service_object) { described_class.new(artifacts, pipeline, report_type) }
    let(:empty_set) { Set.new }
    let(:start_time) { "20241022T11:56:41" }
    let(:scan_object) do
      ::Gitlab::Ci::Reports::Security::Scan.new(
        {
          "type" => report_type,
          "start_time" => start_time,
          "end_time" => "20241022T11:57:39",
          "status" => "success"
        })
    end

    subject(:store_scan_group) { service_object.execute }

    context 'when there is a parsing error' do
      let(:expected_error) { Gitlab::Ci::Parsers::ParserError.new('Foo') }

      before do
        allow(Security::StoreScanService).to receive(:execute).and_raise(expected_error)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'does not propagate the error to the caller' do
        expect { store_scan_group }.not_to raise_error
      end

      it 'tracks the error' do
        store_scan_group

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(expected_error)
      end

      it_behaves_like 'handling the security MR widget caching'
    end

    context 'when there is no error' do
      before do
        allow(Security::StoreScanService).to receive(:execute).and_return(true)
      end

      context 'schema validation' do
        before do
          artifacts.each do |artifact|
            allow(artifact).to receive(:security_report).and_return(mock_report)
            allow(mock_report).to receive(:scan).and_return(scan_object)
          end
        end

        context 'when there is only one report' do
          let(:artifacts) { [artifact_1] }

          it 'accesses the validated security report' do
            store_scan_group

            expect(artifact_1).to have_received(:security_report).with(validate: true).once
          end
        end

        context 'when there are more than one reports' do
          it 'accesses the validated security reports' do
            store_scan_group

            expect(artifact_1).to have_received(:security_report).with(validate: true).once
            expect(artifact_2).to have_received(:security_report).with(validate: true).once
            expect(artifact_3).to have_received(:security_report).with(validate: true).once
            expect(artifact_with_missing_version).to have_received(:security_report).with(validate: true).once
          end
        end
      end

      context 'when the artifacts are not dependency_scanning' do
        context "and reports doesn't pass schema validation" do
          let_it_be(:invalid_artifact_1) { create(:ee_ci_job_artifact, :dast_missing_version, job: create(:ee_ci_build)) }
          let_it_be(:invalid_artifact_2) { create(:ee_ci_job_artifact, :dast_missing_version, job: create(:ee_ci_build)) }
          let_it_be(:invalid_artifact_3) { create(:ee_ci_job_artifact, :dast_missing_version, job: create(:ee_ci_build)) }

          let(:artifacts) { [invalid_artifact_1, invalid_artifact_2, invalid_artifact_3] }

          before do
            artifacts.each do |artifact|
              allow(artifact).to receive(:security_report).and_return(mock_report)
            end
            allow(mock_report).to receive(:scan).and_return(scan_object)
          end

          it 'calls the Security::StoreScanService with ordered artifacts' do
            store_scan_group

            expect(Security::StoreScanService).to have_received(:execute).with(invalid_artifact_1, empty_set, false).ordered
            expect(Security::StoreScanService).to have_received(:execute).with(invalid_artifact_2, empty_set, true).ordered
            expect(Security::StoreScanService).to have_received(:execute).with(invalid_artifact_3, empty_set, true).ordered
          end
        end

        context "some of the reports don't pass schema validation" do
          it 'calls the Security::StoreScanService with correctly ordered artifacts' do
            store_scan_group

            expect(Security::StoreScanService).to have_received(:execute).with(artifact_1, empty_set, false).ordered
            expect(Security::StoreScanService).to have_received(:execute).with(artifact_2, empty_set, true).ordered
            expect(Security::StoreScanService).to have_received(:execute).with(artifact_3, empty_set, true).ordered
            expect(Security::StoreScanService).to have_received(:execute).with(artifact_with_missing_version, empty_set, true).ordered
          end
        end

        context 'and report does pass schema validation' do
          it 'calls the Security::StoreScanService with ordered artifacts' do
            store_scan_group

            expect(Security::StoreScanService).to have_received(:execute).with(artifact_1, empty_set, false).ordered
            expect(Security::StoreScanService).to have_received(:execute).with(artifact_2, empty_set, true).ordered
            expect(Security::StoreScanService).to have_received(:execute).with(artifact_3, empty_set, true).ordered
          end
        end
      end

      context 'when the artifacts are sast' do
        let_it_be(:sast_artifact_1) { create(:ee_ci_job_artifact, :sast, job: create(:ee_ci_build)) }
        let_it_be(:sast_artifact_2) { create(:ee_ci_job_artifact, :sast, job: create(:ee_ci_build)) }
        let_it_be(:sast_artifact_3) { create(:ee_ci_job_artifact, :sast, job: create(:ee_ci_build)) }

        let(:mock_report_1) { instance_double(::Gitlab::Ci::Reports::Security::Report, scanner_order_to: 1) }
        let(:mock_report_2) { instance_double(::Gitlab::Ci::Reports::Security::Report, scanner_order_to: -1) }
        let(:mock_report_3) { instance_double(::Gitlab::Ci::Reports::Security::Report) }
        let(:artifacts) { [sast_artifact_1, sast_artifact_2, sast_artifact_3] }

        before do
          allow(sast_artifact_1).to receive(:security_report).and_return(mock_report_1)
          allow(sast_artifact_2).to receive(:security_report).and_return(mock_report_2)
          allow(sast_artifact_3).to receive(:security_report).and_return(mock_report_3)
          [mock_report_1, mock_report_2, mock_report_3].each do |report|
            allow(report).to receive(:scan).and_return(scan_object)
          end
        end

        it 'calls the Security::StoreScanService with ordered artifacts' do
          store_scan_group

          expect(Security::StoreScanService).to have_received(:execute).with(sast_artifact_2, empty_set, false).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(sast_artifact_3, empty_set, true).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(sast_artifact_1, empty_set, true).ordered
        end
      end

      context 'when the artifacts are dependency_scanning' do
        let(:report_type) { :dependency_scanning }
        let(:mock_report_1) { instance_double(::Gitlab::Ci::Reports::Security::Report, scanner_order_to: 1) }
        let(:mock_report_2) { instance_double(::Gitlab::Ci::Reports::Security::Report, scanner_order_to: -1) }
        let(:mock_report_3) { instance_double(::Gitlab::Ci::Reports::Security::Report) }
        let(:artifacts) { [artifact_1, artifact_2, artifact_3] }

        before do
          allow(artifact_1).to receive(:security_report).and_return(mock_report_1)
          allow(artifact_2).to receive(:security_report).and_return(mock_report_2)
          allow(artifact_3).to receive(:security_report).and_return(mock_report_3)
          [mock_report_1, mock_report_2, mock_report_3].each do |report|
            allow(report).to receive(:scan).and_return(scan_object)
          end
        end

        it 'calls the Security::StoreScanService with ordered artifacts' do
          store_scan_group

          expect(Security::StoreScanService).to have_received(:execute).with(artifact_2, empty_set, false).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(artifact_3, empty_set, true).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(artifact_1, empty_set, true).ordered
        end
      end

      context "when cache miss" do
        let(:mock_report) { instance_double(::Gitlab::Ci::Reports::Security::Report, scanner_order_to: 1) }

        before do
          artifacts.each do |artifact|
            allow(artifact).to receive(:security_report).and_return(mock_report)
          end
          allow(mock_report).to receive(:scan).and_return(scan_object)
        end

        it_behaves_like 'handling the security MR widget caching'
      end

      context 'when recording error rate metrics' do
        before do
          allow(artifact_1).to receive(:security_report).and_return(mock_report)
          allow(artifact_2).to receive(:security_report).and_return(mock_report)
          allow(mock_report).to receive(:scan).and_return(scan_object)
        end

        context 'with success scans' do
          let(:artifacts) { [artifact_1, artifact_2] }

          it 'emits error rate' do
            labels = { scan_type: report_type, feature_category: 'dynamic_application_security_testing' }
            expect(Gitlab::Metrics::SecurityScanSlis.error_rate).to receive(:increment)
                                                                      .with(error: false, labels: labels)
                                                                      .twice

            store_scan_group
          end

          context 'when feature flag disabled' do
            it 'does not emit error rate' do
              stub_feature_flags(security_scan_error_rate: false)

              expect(Gitlab::Metrics::SecurityScanSlis.error_rate).not_to receive(:increment)

              store_scan_group
            end
          end
        end

        context 'with failed scan' do
          let(:artifacts) { [artifact_1, artifact_2, artifact_3] }

          it 'emits error rate' do
            allow(artifact_3).to receive(:security_report).and_return(failure_mock_report)
            allow(failure_mock_report).to receive(:scan).and_return(failure_scan_object)

            labels = { scan_type: report_type, feature_category: 'dynamic_application_security_testing' }
            expect(Gitlab::Metrics::SecurityScanSlis.error_rate).to receive(:increment).with(error: false, labels: labels).twice
            expect(Gitlab::Metrics::SecurityScanSlis.error_rate).to receive(:increment).with(error: true, labels: labels).once

            store_scan_group
          end

          context 'when feature flag disabled' do
            it 'does not emit error rate' do
              stub_feature_flags(security_scan_error_rate: false)

              expect(Gitlab::Metrics::SecurityScanSlis.error_rate).not_to receive(:increment)

              store_scan_group
            end
          end
        end

        context 'with missing security report scan' do
          let(:artifacts) { [artifact_1, artifact_2, artifact_3] }

          it 'does not emit error rate' do
            expect(Gitlab::Metrics::SecurityScanSlis.error_rate).not_to receive(:increment)
          end
        end
      end
    end
  end
end
