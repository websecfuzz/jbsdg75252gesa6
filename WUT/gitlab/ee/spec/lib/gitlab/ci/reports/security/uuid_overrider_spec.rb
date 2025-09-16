# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'UuidOverrider', feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let(:pipeline) { create(:ci_pipeline) }

  let(:vulnerability_identifier) do
    create(:vulnerabilities_identifier, fingerprint: 'e2bd6788a715674769f48fadffd0bd3ea16656f5')
  end

  let(:matching_report_identifier) do
    create(:ci_reports_security_identifier, external_id: vulnerability_identifier.external_id,
      external_type: vulnerability_identifier.external_type)
  end

  describe Gitlab::Ci::Reports::Security::VulnerabilityReportsComparer do
    context 'when a finding has multiple matching signatures with different priorities' do
      def create_multiple_matches_test_data(qualified_signature)
        # Use the same scanner external_id for all findings to ensure the scanner comparison works
        scanner_external_id = 'test-scanner'

        scanner = create(:vulnerabilities_scanner, external_id: scanner_external_id, project: project)

        vuln_finding_offset = create(
          :vulnerabilities_finding,
          project: project,
          uuid: SecureRandom.uuid,
          primary_identifier: vulnerability_identifier,
          scanner: scanner
        )

        vuln_finding_compressed = create(
          :vulnerabilities_finding,
          project: project,
          uuid: SecureRandom.uuid,
          primary_identifier: vulnerability_identifier,
          scanner: scanner
        )

        offset_sha = Digest::SHA1.digest('matching scope offset value') # rubocop:disable Fips/SHA1 -- test data
        compressed_sha = Digest::SHA1.digest('matching scope offset compressed value') # rubocop:disable Fips/SHA1 -- test data

        create(:vulnerabilities_finding_signature, :scope_offset,
          finding: vuln_finding_offset,
          signature_sha: offset_sha)

        create(:vulnerabilities_finding_signature, :scope_offset_compressed,
          finding: vuln_finding_compressed,
          signature_sha: compressed_sha)

        # Create report signatures with appropriate priorities
        offset_signature = ::Gitlab::Ci::Reports::Security::FindingSignature.new(
          algorithm_type: 'scope_offset',
          signature_value: 'matching scope offset value',
          qualified_signature: qualified_signature
        )

        compressed_signature = ::Gitlab::Ci::Reports::Security::FindingSignature.new(
          algorithm_type: 'scope_offset_compressed',
          signature_value: 'matching scope offset compressed value',
          qualified_signature: qualified_signature
        )

        allow(offset_signature).to receive_messages(priority: 1, signature_sha: offset_sha)
        allow(compressed_signature).to receive_messages(priority: 2, signature_sha: compressed_sha)

        report_scanner = create(:ci_reports_security_scanner, external_id: scanner_external_id)

        allow_next_instance_of(Gitlab::Ci::Reports::Security::UUIDOverrider) do |instance|
          allow(instance).to receive(:scanners).and_return(
            { scanner_external_id => scanner }
          )
        end

        report_finding = create(
          :ci_reports_security_finding,
          uuid: SecureRandom.uuid,
          vulnerability_finding_signatures_enabled: true,
          signatures: [offset_signature, compressed_signature],
          identifiers: [matching_report_identifier],
          scanner: report_scanner
        )

        report = create(:ci_reports_security_report, findings: [report_finding], pipeline: pipeline)

        {
          vuln_finding_offset: vuln_finding_offset,
          vuln_finding_compressed: vuln_finding_compressed,
          report_finding: report_finding,
          report: report
        }
      end

      context 'when vulnerability_signatures_dedup_by_type feature flag is enabled' do
        before do
          # Mock dedup_by_type_enabled? to return true for all FindingSignature instances (FF enabled)
          allow_next_instance_of(::Vulnerabilities::FindingSignature) do |instance|
            allow(instance).to receive(:dedup_by_type_enabled?).and_return(true)
          end
        end

        let(:qualified_signature) { true }
        let(:test_data) { create_multiple_matches_test_data(qualified_signature) }

        it 'overrides the UUID using the highest numeric priority signature' do
          stub_licensed_features(vulnerability_finding_signatures: true)

          override_uuids = Gitlab::Ci::Reports::Security::UUIDOverrider.new(project, [test_data[:report_finding]])
          override_uuids.execute

          # With flag enabled, higher priority wins (2 > 1)
          # So compressed signature (priority 2) should be used
          expect(test_data[:report_finding].uuid).to eq(test_data[:vuln_finding_compressed].uuid)
          expect(test_data[:report_finding].uuid).not_to eq(test_data[:vuln_finding_offset].uuid)
        end
      end

      context 'when vulnerability_signatures_dedup_by_type feature flag is disabled' do
        before do
          stub_feature_flags(vulnerability_signatures_dedup_by_type: false)
          # Mock dedup_by_type_enabled? to return false for all FindingSignature instances
          allow_next_instance_of(::Vulnerabilities::FindingSignature) do |instance|
            allow(instance).to receive(:dedup_by_type_enabled?).and_return(false)
          end
        end

        let(:qualified_signature) { false }
        let(:test_data) { create_multiple_matches_test_data(qualified_signature) }

        it 'overrides the UUID using the lowest numeric priority signature' do
          stub_licensed_features(vulnerability_finding_signatures: true)

          override_uuids = Gitlab::Ci::Reports::Security::UUIDOverrider.new(project, [test_data[:report_finding]])
          override_uuids.execute

          # With flag disabled, lower priority wins (1 < 2)
          # So offset signature (priority 1) should is used (unintended old behaviour)
          expect(test_data[:report_finding].uuid).to eq(test_data[:vuln_finding_offset].uuid)
          expect(test_data[:report_finding].uuid).not_to eq(test_data[:vuln_finding_compressed].uuid)
        end
      end
    end
  end
end
