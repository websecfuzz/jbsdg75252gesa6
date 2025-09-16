# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicyViolation, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:scan_result_policy_read) }
    it { is_expected.to belong_to(:approval_policy_rule) }
    it { is_expected.to belong_to(:merge_request) }
    it { is_expected.to have_one(:security_policy).through(:approval_policy_rule) }
  end

  describe 'validations' do
    let_it_be(:violation) { create(:scan_result_policy_violation) }

    subject { violation }

    it { is_expected.to(validate_uniqueness_of(:scan_result_policy_id).scoped_to(%i[merge_request_id])) }

    describe 'violation_data' do
      it { is_expected.not_to allow_value('string').for(:violation_data) }
      it { is_expected.to allow_value({}).for(:violation_data) }

      it 'allows combination of all possible values' do
        is_expected.to allow_value(
          {
            violations: {
              scan_finding: { uuids: { newly_detected: ['123'], previously_existing: ['456'] } },
              license_scanning: { 'MIT' => ['A'] },
              any_merge_request: { commits: ['abcd1234'] }
            },
            context: { pipeline_ids: [123], target_pipeline_ids: [456] },
            errors: [{ error: 'SCAN_REMOVED', missing_scans: ['sast'] }]
          }
        ).for(:violation_data)
      end

      describe 'errors' do
        it do
          is_expected.to allow_value(
            { errors: [{ error: 'SCAN_REMOVED', missing_scans: ['sast'] }] }
          ).for(:violation_data)
        end
      end

      it { is_expected.not_to allow_value({ errors: [{}] }).for(:violation_data) }

      describe 'violations' do
        using RSpec::Parameterized::TableSyntax

        describe 'commits' do
          where(:report_type, :data, :valid) do
            :any_merge_request | { commits: ['abcd1234'] } | true
            :any_merge_request | { commits: true }         | true
            :any_merge_request | { commits: 'abcd1234' }   | false
            :any_merge_request | { commits: [] }           | false
          end

          with_them do
            it do
              if valid
                expect(violation).to allow_value(violations: { report_type => data }).for(:violation_data)
              else
                expect(violation).not_to allow_value(violations: { report_type => data }).for(:violation_data)
              end
            end
          end
        end
      end
    end
  end

  describe '.for_approval_rules' do
    let_it_be(:violation) { create(:scan_result_policy_violation) }

    subject { described_class.for_approval_rules(approval_rules) }

    context 'when approval rules are empty' do
      let(:approval_rules) { [] }

      it { is_expected.to be_empty }
    end

    context 'when approval rules are present' do
      let_it_be(:project) { create(:project) }
      let_it_be(:scan_result_policy_read_1) { create(:scan_result_policy_read, project: project) }
      let_it_be(:scan_result_policy_read_2) { create(:scan_result_policy_read, project: project) }
      let_it_be(:scan_result_policy_read_3) { create(:scan_result_policy_read, project: project) }
      let_it_be(:other_violations) do
        [
          create(:scan_result_policy_violation, project: project, scan_result_policy_read: scan_result_policy_read_2),
          create(:scan_result_policy_violation, project: project, scan_result_policy_read: scan_result_policy_read_3)
        ]
      end

      let(:approval_rules) do
        create_list(:report_approver_rule, 1, :scan_finding, scan_result_policy_read: scan_result_policy_read_1)
      end

      let_it_be(:scan_finding_violation) do
        create(:scan_result_policy_violation, project: project, scan_result_policy_read: scan_result_policy_read_1)
      end

      it { is_expected.to contain_exactly scan_finding_violation }
    end
  end

  describe '.with_violation_data' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
    let_it_be(:scan_result_policy_read_2) { create(:scan_result_policy_read, project: project) }
    let_it_be(:violation_with_data) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read)
    end

    let_it_be(:violation_without_data) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read_2, violation_data: nil)
    end

    subject { described_class.with_violation_data }

    it { is_expected.to contain_exactly violation_with_data }
  end

  describe '.without_violation_data' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
    let_it_be(:scan_result_policy_read_2) { create(:scan_result_policy_read, project: project) }
    let_it_be(:violation_with_data) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read)
    end

    let_it_be(:violation_without_data) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read_2, violation_data: nil)
    end

    subject { described_class.without_violation_data }

    it { is_expected.to contain_exactly violation_without_data }
  end

  describe '.trim_violations' do
    subject(:trimmed_violations) { described_class.trim_violations(violations) }

    let(:violations) { ['uuid'] * (Security::ScanResultPolicyViolation::MAX_VIOLATIONS + 2) }

    it 'returns MAX_VIOLATIONS+1 number of violations' do
      expect(trimmed_violations.size).to eq Security::ScanResultPolicyViolation::MAX_VIOLATIONS + 1
      expect(trimmed_violations).to eq(violations[..Security::ScanResultPolicyViolation::MAX_VIOLATIONS])
    end

    context 'when violations are nil' do
      let(:violations) { nil }

      it { is_expected.to be_empty }
    end
  end

  describe '.running' do
    let_it_be(:running_violation) { create(:scan_result_policy_violation, :running) }
    let_it_be(:failed_violation) { create(:scan_result_policy_violation, :failed) }

    it 'returns only running violations' do
      expect(described_class.running).to contain_exactly(running_violation)
    end
  end
end
