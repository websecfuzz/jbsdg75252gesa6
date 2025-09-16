# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }

  let(:base_vulnerability) { build(:security_finding) }
  let(:base_report) { build(:ci_reports_security_aggregated_findings, findings: [base_vulnerability]) }

  let(:head_vulnerability) do
    build(:security_finding, uuid: base_vulnerability.uuid)
  end

  let(:head_report) { build(:ci_reports_security_aggregated_findings, findings: [head_vulnerability]) }

  subject(:report_comparer) { described_class.new(project, base_report, head_report) }

  describe '#base_report_out_of_date' do
    context 'with base pipeline older than one week' do
      let(:pipeline) { build(:ci_pipeline, created_at: 1.week.ago - 60.seconds) }
      let(:base_report) { build(:ci_reports_security_aggregated_findings, pipeline: pipeline) }

      it 'is out of date' do
        expect(report_comparer.base_report_out_of_date).to be true
      end
    end

    context 'with base pipeline less than one week old' do
      let(:pipeline) { build(:ci_pipeline, created_at: 1.week.ago + 60.seconds) }
      let(:base_report) { build(:ci_reports_security_aggregated_findings, pipeline: pipeline) }

      it 'is not out of date' do
        expect(report_comparer.base_report_out_of_date).to be false
      end
    end
  end

  describe '#added' do
    let(:new_vuln) { build(:security_finding) }
    let(:low_vuln) { build(:security_finding, severity: Enums::Vulnerability.severity_levels[:low]) }

    context 'with new vulnerability' do
      let!(:head_report) do
        build(:ci_reports_security_aggregated_findings, findings: [head_vulnerability, new_vuln])
      end

      it 'returns the new vulnerability' do
        expect(report_comparer.added).to match_array([new_vuln])
      end
    end

    context 'with a dismissed Vulnerability on the default branch' do
      let_it_be(:dismissed_vulnerability) { create(:vulnerability, :dismissed, :with_finding) }
      let(:dismissed_on_default_branch) do
        build(
          :security_finding,
          uuid: dismissed_vulnerability.finding.uuid
        )
      end

      let(:head_report) do
        build(:ci_reports_security_aggregated_findings,
          findings: [dismissed_on_default_branch, new_vuln, head_vulnerability])
      end

      it 'doesnt report the dismissed Vulnerability' do
        expect(report_comparer.added).not_to include(dismissed_on_default_branch)
        expect(report_comparer.added).to contain_exactly(new_vuln)
      end
    end

    describe 'number of findings' do
      let(:head_report) do
        build(:ci_reports_security_aggregated_findings, findings: [head_vulnerability, new_vuln, low_vuln])
      end

      before do
        stub_const("#{described_class}::MAX_FINDINGS_COUNT", 1)
      end

      it 'returns no more than `MAX_FINDINGS_COUNT`' do
        expect(report_comparer.added).to eq([new_vuln])
      end
    end

    describe 'metric tracking' do
      let(:head_report) do
        build(:ci_reports_security_aggregated_findings, findings: [head_vulnerability, new_vuln, low_vuln])
      end

      it 'measures the execution time of the uuid gathering query' do
        expect(Gitlab::Metrics).to receive(:measure)
                                    .with(described_class::VULNERABILITY_FILTER_METRIC_KEY)
                                    .and_call_original

        report_comparer.added
      end
    end
  end

  describe '#fixed' do
    let(:new_vuln) { build(:security_finding) }
    let(:low_vuln) { build(:security_finding, severity: Enums::Vulnerability.severity_levels[:low]) }

    context 'with fixed vulnerability' do
      let!(:base_report) do
        build(:ci_reports_security_aggregated_findings, findings: [base_vulnerability, new_vuln])
      end

      it 'returns the fixed vulnerability' do
        expect(report_comparer.fixed).to match_array([new_vuln])
      end
    end

    context 'with a dismissed Vulnerability on the default branch' do
      let_it_be(:dismissed_vulnerability) { create(:vulnerability, :dismissed, :with_finding) }
      let(:dismissed_on_default_branch) do
        build(
          :security_finding,
          uuid: dismissed_vulnerability.finding.uuid
        )
      end

      let(:base_report) do
        build(:ci_reports_security_aggregated_findings,
          findings: [dismissed_on_default_branch, new_vuln, base_vulnerability])
      end

      it 'doesnt report the dismissed Vulnerability' do
        expect(report_comparer.fixed).not_to include(dismissed_on_default_branch)
        expect(report_comparer.fixed).to contain_exactly(new_vuln)
      end
    end

    describe 'number of findings' do
      let(:base_report) do
        build(:ci_reports_security_aggregated_findings, findings: [base_vulnerability, new_vuln, low_vuln])
      end

      before do
        stub_const("#{described_class}::MAX_FINDINGS_COUNT", 1)
      end

      it 'returns no more than `MAX_FINDINGS_COUNT`' do
        expect(report_comparer.fixed).to eq([new_vuln])
      end
    end

    describe 'metric tracking' do
      let(:base_report) do
        build(:ci_reports_security_aggregated_findings, findings: [base_vulnerability, new_vuln, low_vuln])
      end

      it 'measures the execution time of the uuid gathering query' do
        expect(Gitlab::Metrics).to receive(:measure)
                                    .with(described_class::VULNERABILITY_FILTER_METRIC_KEY)
                                    .and_call_original

        report_comparer.fixed
      end
    end
  end

  describe 'with empty vulnerabilities' do
    let(:empty_report) { build(:ci_reports_security_aggregated_findings, findings: []) }

    it 'returns empty array when reports are not present' do
      comparer = described_class.new(project, empty_report, empty_report)

      expect(comparer.fixed).to eq([])
      expect(comparer.added).to eq([])
    end

    it 'returns added vulnerability when base is empty and head is not empty' do
      comparer = described_class.new(project, empty_report, head_report)

      expect(comparer.fixed).to eq([])
      expect(comparer.added).to eq([head_vulnerability])
    end

    it 'returns fixed vulnerability when head is empty and base is not empty' do
      comparer = described_class.new(project, base_report, empty_report)

      expect(comparer.fixed).to eq([base_vulnerability])
      expect(comparer.added).to eq([])
    end
  end
end
