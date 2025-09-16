# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PolicyViolationDetails, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :repository) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:policy1) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:policy2) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:policy3) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:policy_warn_mode) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let(:warn_mode_db_policy) do
    create(:security_policy, :warn_mode, policy_index: 3, name: 'Warn mode',
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let(:warn_mode_policy_rule) { create(:approval_policy_rule, security_policy: warn_mode_db_policy) }

  let_it_be(:approver_rule_policy1) do
    create(:report_approver_rule, :scan_finding, merge_request: merge_request,
      scan_result_policy_read: policy1, name: 'Policy 1')
  end

  let_it_be(:approver_rule_policy2) do
    create(:report_approver_rule, :license_scanning, merge_request: merge_request,
      scan_result_policy_read: policy2, name: 'Policy 2')
  end

  let_it_be_with_reload(:approver_rule_policy3) do
    create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
      scan_result_policy_read: policy3, name: 'Policy 3')
  end

  let_it_be_with_reload(:approver_rule_policy_warn_mode) do
    create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
      scan_result_policy_read: policy_warn_mode, name: 'Warn mode')
  end

  let_it_be(:uuid) { SecureRandom.uuid }
  let_it_be(:uuid_previous) { SecureRandom.uuid }
  let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }
  let_it_be(:pipeline) do
    create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
      ref: merge_request.source_branch, sha: merge_request.diff_head_sha,
      merge_requests_as_head_pipeline: [merge_request])
  end

  let_it_be(:ci_build) { pipeline.builds.first }

  let(:details) { described_class.new(merge_request) }

  def build_violation_details(policy, data, status = :failed)
    create(:scan_result_policy_violation, status, project: project, merge_request: merge_request,
      scan_result_policy_read: policy, violation_data: data)
  end

  describe '#violations' do
    subject(:violations) { details.violations }

    let(:scan_finding_violation_data) do
      { 'violations' => { 'scan_finding' => { 'newly_detected' => ['uuid'] } } }
    end

    let(:license_scanning_violation_data) do
      { 'violations' => { 'license_scanning' => { 'MIT' => ['A'] } } }
    end

    let(:any_merge_request_violation_data) do
      { 'violations' => { 'any_merge_request' => { 'commits' => true } } }
    end

    let(:normal_db_policy) do
      create(:security_policy, policy_index: 1,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let(:warn_mode_policy_rule) { create(:approval_policy_rule, security_policy: warn_mode_db_policy) }
    let(:normal_policy_rule) { create(:approval_policy_rule, security_policy: normal_db_policy) }

    where(:policy, :name, :report_type, :data, :status, :is_warning, :policy_rule, :is_warn_mode) do
      [
        [
          ref(:policy1),
          'Policy 1',
          'scan_finding',
          ref(:scan_finding_violation_data),
          :failed,
          false,
          ref(:normal_policy_rule),
          false
        ],
        [
          ref(:policy2),
          'Policy 2',
          'license_scanning',
          ref(:license_scanning_violation_data),
          :failed,
          false,
          ref(:normal_policy_rule),
          false
        ],
        [
          ref(:policy3),
          'Policy 3',
          'any_merge_request',
          ref(:any_merge_request_violation_data),
          :failed,
          false,
          ref(:normal_policy_rule),
          false
        ],
        [
          ref(:policy1),
          'Policy 1',
          'scan_finding',
          ref(:scan_finding_violation_data),
          :warn,
          true,
          ref(:warn_mode_policy_rule),
          true
        ]
      ]
    end

    with_them do
      before do
        create(:scan_result_policy_violation, status, project: project, merge_request: merge_request,
          scan_result_policy_read: policy, violation_data: data, approval_policy_rule: policy_rule)
      end

      it 'has correct attributes', :aggregate_failures do
        expect(violations.size).to eq 1

        violation = violations.first
        expect(violation.name).to eq 'Policy'
        expect(violation.report_type).to eq report_type
        expect(violation.data).to eq data
        expect(violation.scan_result_policy_id).to eq policy.id
        expect(violation.warning).to eq is_warning
        expect(violation.status).to eq status.to_s
        expect(violation.warn_mode).to eq is_warn_mode
      end
    end

    context 'when there is a violation that has no approval rules associated with it' do
      let_it_be(:policy_without_rules) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      before do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy_without_rules, violation_data: any_merge_request_violation_data)
      end

      it 'is ignored' do
        expect(violations).to be_empty
      end
    end
  end

  describe '#fail_closed_policies' do
    subject(:fail_closed_policies) { details.fail_closed_policies }

    let!(:policy1_violation) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: policy1)
    end

    let!(:policy2_violation) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: policy2)
    end

    let(:warn_mode_policy_rule) { create(:approval_policy_rule, security_policy: warn_mode_db_policy) }

    before do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: policy3)
      create(:report_approver_rule, :scan_finding, merge_request: merge_request,
        scan_result_policy_read: policy3, name: 'Other')
      create(:report_approver_rule, :scan_finding, merge_request: merge_request,
        scan_result_policy_read: policy3, name: 'Other 2')
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: policy_warn_mode, approval_policy_rule: warn_mode_policy_rule)
    end

    it { is_expected.to contain_exactly 'Policy', 'Other' }

    it 'excludes warn mode policies' do
      expect(fail_closed_policies).not_to include('Warn mode')
    end

    context 'when filtered by report_type' do
      subject(:fail_closed_policies) { details.fail_closed_policies(:license_scanning) }

      it { is_expected.to contain_exactly 'Policy' }
    end

    context 'when violation has status warn' do
      let!(:policy1_violation) do
        create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
          scan_result_policy_read: policy1)
      end

      let!(:policy2_violation) do
        create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
          scan_result_policy_read: policy2)
      end

      it('is excluded') { is_expected.to contain_exactly 'Other' }
    end

    context 'when security_policy_approval_warn_mode feature flag is disabled' do
      before do
        stub_feature_flags(security_policy_approval_warn_mode: false)
      end

      it 'includes warn mode policies' do
        expect(fail_closed_policies).to include('Warn mode')
      end

      it { is_expected.to contain_exactly 'Policy', 'Other', 'Warn mode' }
    end
  end

  describe '#fail_open_policies' do
    subject(:fail_open_policies) { details.fail_open_policies }

    before do
      create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
        scan_result_policy_read: policy1)
      create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
        scan_result_policy_read: policy2)
      create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
        scan_result_policy_read: policy3)
      create(:report_approver_rule, :scan_finding, merge_request: merge_request,
        scan_result_policy_read: policy3, name: 'Other')
      create(:report_approver_rule, :scan_finding, merge_request: merge_request,
        scan_result_policy_read: policy3, name: 'Other 2')
      create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
        scan_result_policy_read: policy_warn_mode, approval_policy_rule: warn_mode_policy_rule)
    end

    it { is_expected.to contain_exactly 'Other' }

    context 'when security_policy_approval_warn_mode feature flag is disabled' do
      before do
        stub_feature_flags(security_policy_approval_warn_mode: false)
      end

      it 'includes warn mode policies' do
        expect(fail_open_policies).to contain_exactly 'Other', 'Warn mode'
      end
    end
  end

  describe '#warn_mode_policies' do
    subject(:warn_mode_policies) { details.warn_mode_policies }

    let(:normal_db_policy) do
      create(:security_policy, policy_index: 1,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let(:normal_policy_rule) { create(:approval_policy_rule, security_policy: normal_db_policy) }

    context 'when there are a mix of policy types' do
      before do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy1, approval_policy_rule: warn_mode_policy_rule)
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy2, approval_policy_rule: normal_policy_rule)
      end

      it 'returns only warn mode policies' do
        expect(warn_mode_policies).to contain_exactly(warn_mode_db_policy)
      end
    end

    context 'when there are multiple warn mode policies' do
      let(:another_warn_mode_db_policy) do
        create(:security_policy, :warn_mode, policy_index: 2,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let(:another_warn_policy_rule) { create(:approval_policy_rule, security_policy: another_warn_mode_db_policy) }

      before do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy1, approval_policy_rule: warn_mode_policy_rule)
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy3, approval_policy_rule: another_warn_policy_rule)
      end

      it 'returns all warn mode policies' do
        expect(warn_mode_policies).to contain_exactly(warn_mode_db_policy, another_warn_mode_db_policy)
      end
    end
  end

  describe 'scan finding violations' do
    let_it_be_with_reload(:policy1_violation) do
      build_violation_details(policy1,
        context: { pipeline_ids: [pipeline.id] },
        violations: { scan_finding: { uuids: { newly_detected: [uuid], previously_existing: [uuid_previous] } } }
      )
    end

    let_it_be_with_reload(:policy1_security_finding) do
      pipeline_scan = create(:security_scan, :succeeded, build: ci_build, scan_type: 'dependency_scanning')
      create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner, severity: 'high',
        uuid: uuid, location: { start_line: 3, file: '.env' })
    end

    let_it_be_with_reload(:policy1_vulnerability_finding) do
      create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner,
        uuid: uuid_previous, name: 'AWS API key')
    end

    before_all do
      # Unrelated violation that is expected to be filtered out
      build_violation_details(policy3, violations: { any_merge_request: { commits: true } })
    end

    describe '#new_scan_finding_violations' do
      let(:violation) { new_scan_finding_violations.first }

      subject(:new_scan_finding_violations) { details.new_scan_finding_violations }

      context 'with additional unrelated violation' do
        before do
          build_violation_details(policy2,
            violations: { scan_finding: { uuids: { previously_existing: [uuid_previous] } } }
          )
        end

        it 'returns only related new scan finding violations', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.name).to eq 'Test finding'
          expect(violation.severity).to eq 'high'
          expect(violation.path).to match(/^http.+\.env#L3$/)
          expect(violation.location).to match(file: '.env', start_line: 3)
        end
      end

      context 'with multiple pipelines detecting the same uuid' do
        let_it_be(:other_pipeline) do
          create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
            ref: merge_request.source_branch, sha: merge_request.diff_head_sha)
        end

        before_all do
          pipeline_scan = create(:security_scan, :succeeded, build: other_pipeline.builds.first,
            scan_type: 'dependency_scanning')
          create(:security_finding, scan: pipeline_scan, scanner: scanner, severity: 'high',
            uuid: uuid, location: { start_line: 3, file: '.env' })
          policy1_violation.update!(violation_data: policy1_violation.violation_data.merge(
            context: { pipeline_ids: [pipeline.id, other_pipeline.id] }
          ))
        end

        it 'returns only one violation', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.name).to eq 'Test finding'
          expect(violation.severity).to eq 'high'
          expect(violation.path).to match(/^http.+\.env#L3$/)
          expect(violation.location).to match(file: '.env', start_line: 3)
        end
      end

      context 'when multiple policies containing the same uuid' do
        before do
          build_violation_details(policy2,
            context: { pipeline_ids: [pipeline.id] },
            violations: {
              scan_finding: { uuids: { newly_detected: [uuid] } }
            }
          )
        end

        it 'returns de-duplicated violations', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.name).to eq 'Test finding'
          expect(violation.severity).to eq 'high'
          expect(violation.path).to match(/^http.+\.env#L3$/)
          expect(violation.location).to match(file: '.env', start_line: 3)
        end
      end

      context 'when the referenced finding does not contain any finding_data' do
        before do
          policy1_security_finding.update!(finding_data: {})
        end

        it 'returns violations without location, path and name', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.severity).to eq 'high'
          expect(violation.name).to be_nil
          expect(violation.path).to be_nil
          expect(violation.location).to be_nil
        end
      end
    end

    describe '#previous_scan_finding_violations' do
      let(:violation) { previous_scan_finding_violations.first }

      subject(:previous_scan_finding_violations) { details.previous_scan_finding_violations }

      context 'with additional unrelated violation' do
        before do
          build_violation_details(policy2,
            context: { pipeline_ids: [pipeline.id] },
            violations: { scan_finding: { uuids: { newly_detected: [uuid] } } }
          )
        end

        it 'returns only related previous scan finding violations', :aggregate_failures do
          expect(previous_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'secret_detection'
          expect(violation.name).to eq 'AWS API key'
          expect(violation.severity).to eq 'critical'
          expect(violation.path).to match(/^http.+aws-key\.py#L5$/)
          expect(violation.location).to match(hash_including(file: 'aws-key.py', start_line: 5))
        end
      end

      context 'when multiple policies containing the same uuid' do
        before do
          build_violation_details(policy2,
            violations: {
              scan_finding: { uuids: { previously_existing: [uuid_previous] } }
            }
          )
        end

        it 'returns de-duplicated violations', :aggregate_failures do
          expect(previous_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'secret_detection'
          expect(violation.name).to eq 'AWS API key'
          expect(violation.severity).to eq 'critical'
          expect(violation.path).to match(/^http.+aws-key\.py#L5$/)
          expect(violation.location).to match(hash_including(file: 'aws-key.py', start_line: 5))
        end
      end

      context 'when the referenced finding does not contain any raw_metadata' do
        before do
          policy1_vulnerability_finding.update! raw_metadata: {}
        end

        it 'returns violations without location and path', :aggregate_failures do
          expect(previous_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'secret_detection'
          expect(violation.severity).to eq 'critical'
          expect(violation.name).to eq 'AWS API key'
          expect(violation.path).to be_nil
          expect(violation.location).to eq({})
        end
      end
    end
  end

  describe '#any_merge_request_violations' do
    subject(:violations) { details.any_merge_request_violations }

    before do
      build_violation_details(policy3, violations: { any_merge_request: { commits: commits } })
      # Unrelated violation that is expected to be filtered out
      build_violation_details(policy1,
        context: { pipeline_ids: [pipeline.id] },
        violations: { scan_finding: { uuids: { newly_detected: [uuid], previously_existing: [uuid_previous] } } }
      )
    end

    context 'when commits is boolean' do
      let(:commits) { true }

      it 'returns only any_merge_request violations', :aggregate_failures do
        expect(violations.size).to eq 1

        violation = violations.first
        expect(violation.name).to eq 'Policy'
        expect(violation.commits).to eq true
      end
    end

    context 'when commits is array' do
      let(:commits) { ['abcd1234'] }

      it 'returns only any_merge_request violations', :aggregate_failures do
        expect(violations.size).to eq 1

        violation = violations.first
        expect(violation.name).to eq 'Policy'
        expect(violation.commits).to match_array(['abcd1234'])
      end
    end
  end

  describe '#license_scanning_violations' do
    subject(:violations) { details.license_scanning_violations }

    context 'when a violation exists' do
      context 'when software license matching the name does not exists' do
        before do
          build_violation_details(policy1, violations: { license_scanning: { 'License' => %w[B C D] } })
        end

        it 'returns list of licenses with dependencies' do
          expect(violations.size).to eq 1
          violation = violations.first
          expect(violation.license).to eq 'License'
          expect(violation.dependencies).to contain_exactly('B', 'C', 'D')
          expect(violation.url).to be_nil
        end
      end

      context 'when software license matching the name exists' do
        before do
          build_violation_details(policy1, violations: { license_scanning: { 'MIT License' => %w[B C D] } })
        end

        it 'includes license URL' do
          violation = violations.first
          expect(violation.url).to eq 'https://spdx.org/licenses/MIT.html'
        end

        context 'when multiple violations exist' do
          before do
            build_violation_details(policy2,
              violations: { license_scanning: { 'MIT License' => %w[A B], 'w3m License' => %w[A] } }
            )
          end

          it 'merges the licenses and dependencies' do
            expect(violations.size).to eq 2
            expect(violations).to contain_exactly(
              Security::ScanResultPolicies::PolicyViolationDetails::LicenseScanningViolation.new(license: 'w3m License',
                dependencies: %w[A], url: 'https://spdx.org/licenses/w3m.html'),
              Security::ScanResultPolicies::PolicyViolationDetails::LicenseScanningViolation.new(license: 'MIT License',
                dependencies: %w[A B C D], url: 'https://spdx.org/licenses/MIT.html')
            )
          end
        end
      end
    end
  end

  describe '#errors' do
    subject(:errors) { details.errors }

    context 'with SCAN_REMOVED error' do
      let_it_be(:violation1) do
        build_violation_with_error(policy1,
          Security::ScanResultPolicyViolation::ERRORS[:scan_removed], 'missing_scans' => %w[secret_detection])
      end

      it 'returns associated error messages' do
        expect(errors.pluck(:message)).to contain_exactly(
          'There is a mismatch between the scans of the source and target pipelines. ' \
            'The following scans are missing: Secret detection'
        )
      end
    end

    context 'with TARGET_PIPELINE_MISSING error' do
      let_it_be(:violation1) do
        build_violation_with_error(policy1, Security::ScanResultPolicyViolation::ERRORS[:target_pipeline_missing])
      end

      it 'returns associated error messages' do
        expect(errors.pluck(:message)).to contain_exactly(
          'Pipeline configuration error: SBOM reports required by policy `Policy` ' \
          'could not be found on the target branch.'
        )
      end
    end

    context 'with ARTIFACTS_MISSING error' do
      context 'with scan_finding report_type' do
        let_it_be(:violation1) do
          build_violation_with_error(policy1, Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing])
        end

        it 'returns associated error messages' do
          expect(errors.pluck(:message)).to contain_exactly(
            'Pipeline configuration error: Security reports required by policy `Policy` could not be found.'
          )
        end
      end

      context 'with license_scanning report_type' do
        let_it_be(:violation1) do
          build_violation_with_error(policy2, Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing])
        end

        it 'returns associated error messages' do
          expect(errors.pluck(:message)).to contain_exactly(
            'Pipeline configuration error: SBOM reports required by policy `Policy` could not be found.'
          )
        end
      end

      context 'with unsupported report_type' do
        let_it_be(:violation1) do
          build_violation_with_error(policy3, Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing])
        end

        it 'returns associated error messages' do
          expect(errors.pluck(:message)).to contain_exactly(
            'Pipeline configuration error: Artifacts required by policy `Policy` could not be found ' \
            '(any_merge_request).'
          )
        end
      end
    end

    context 'with EVALUATION_SKIPPED error' do
      let_it_be(:violation1) do
        build_violation_with_error(policy1,
          Security::ScanResultPolicyViolation::ERRORS[:evaluation_skipped])
      end

      it 'returns associated error messages' do
        expect(errors.pluck(:message)).to contain_exactly(
          'Policy `Policy` could not be evaluated within the specified timeframe and, as a result, ' \
          'approvals are required for the policy. Ensure that scanners are present in the latest pipeline.'
        )
      end
    end

    context 'with PIPELINE_FAILED error' do
      let_it_be(:violation1) do
        build_violation_with_error(policy1,
          Security::ScanResultPolicyViolation::ERRORS[:pipeline_failed])
      end

      it 'returns associated error messages' do
        expect(errors.pluck(:message)).to contain_exactly(
          'Policy `Policy` could not be evaluated because the latest pipeline failed. ' \
            'Ensure that the pipeline is configured properly and the scanners are present.'
        )
      end
    end

    context 'with unsupported error' do
      let_it_be(:violation1) { build_violation_with_error(policy2, 'unsupported') }

      it 'results in unknown error message' do
        expect(errors.pluck(:error)).to contain_exactly('UNKNOWN')
        expect(errors.pluck(:message)).to contain_exactly('Unknown error: unsupported')
      end
    end
  end

  describe '#fail_open_messages' do
    subject(:fail_open_messages) { details.fail_open_messages }

    context 'with a supported error' do
      context 'when violation is warn' do
        context 'when error maps to a string' do
          let_it_be(:violation1) do
            build_violation_with_error(policy1, Security::ScanResultPolicyViolation::ERRORS[:scan_removed], :warn)
          end

          it 'returns associated fail-open message' do
            expect(fail_open_messages).to contain_exactly(
              'Confirm that all scanners from the target branch are present on the source branch.'
            )
          end
        end

        context 'when error maps to a hash' do
          let_it_be(:violation1) do
            build_violation_with_error(policy1, Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing], :warn)
          end

          it 'returns associated fail-open message for the policy report_type' do
            expect(fail_open_messages).to contain_exactly(
              'Confirm that scanners are properly configured and producing results. ' \
              'Vulnerability detection depends on successful execution of security scan jobs in the ' \
              'target and source branches.'
            )
          end
        end
      end

      context 'when violation is failed' do
        let_it_be(:violation1) do
          build_violation_with_error(policy1, Security::ScanResultPolicyViolation::ERRORS[:scan_removed], :failed)
        end

        it { is_expected.to be_empty }
      end
    end

    context 'with unsupported error' do
      let_it_be(:violation1) { build_violation_with_error(policy2, 'unsupported', :failed) }

      it { is_expected.to be_empty }
    end
  end

  describe '#comparison_pipelines' do
    subject(:comparison_pipelines) { details.comparison_pipelines }

    before do
      approver_rule_policy3.update!(report_type: :scan_finding)
      # scan_finding
      build_violation_details(policy1, 'context' => { 'pipeline_ids' => [2, 3], 'target_pipeline_ids' => [1] })
      build_violation_details(policy3, 'context' => { 'pipeline_ids' => [3, 4], 'target_pipeline_ids' => [1, 3] })
      # license_scanning
      build_violation_details(policy2, 'context' => { 'pipeline_ids' => [3, 4], 'target_pipeline_ids' => [1, 2] })
    end

    it 'returns associated, deduplicated pipeline ids grouped by report_type', :aggregate_failures do
      expect(comparison_pipelines).to contain_exactly(
        Security::ScanResultPolicies::PolicyViolationDetails::ComparisonPipelines.new(
          report_type: 'scan_finding', source: [2, 3, 4].to_set, target: [1, 3].to_set
        ),
        Security::ScanResultPolicies::PolicyViolationDetails::ComparisonPipelines.new(
          report_type: 'license_scanning', source: [3, 4].to_set, target: [1, 2].to_set
        )
      )
    end
  end

  describe '#violations_count' do
    before do
      build_violation_details(policy3, violations: { any_merge_request: { commits: true } })
      build_violation_details(policy1, violations: { license_scanning: { 'MIT License' => %w[B C D] } })
    end

    it 'counts all violations' do
      expect(details.violations_count).to eq(2)
    end
  end

  private

  def build_violation_with_error(policy, error, status = :failed, **extra_data)
    build_violation_details(policy, { 'errors' => [{ 'error' => error, **extra_data }] }, status)
  end
end
