# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PolicyViolationComment, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :repository) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let(:existing_comment) { build(:note, author: build(:user, :security_bot)) }
  let(:comment) { described_class.new(existing_comment, merge_request) }

  def build_comment(reports: [], optional_approvals: [])
    build(:note,
      author: build(:user, :security_bot),
      note: [
        described_class::MESSAGE_HEADER,
        "<!-- violated_reports: #{reports.join(',')} -->",
        "<!-- optional_approvals: #{optional_approvals.join(',')} -->",
        "Comment body"
      ].join("\n"))
  end

  describe '#reports' do
    subject(:execute) { comment.reports }

    where(:existing_comment, :expected) do
      nil | []
      build_comment(reports: %w[scan_finding]) | %w[scan_finding]
      build_comment(reports: %w[scan_finding license_scanning]) | %w[scan_finding license_scanning]
      build_comment(reports: %w[scan_finding invalid]) | %w[scan_finding]
      build(:note, note: "invalid format") | []
    end

    with_them do
      it { is_expected.to match_array(expected) }
    end
  end

  describe '#optional_approval_reports' do
    subject(:execute) { comment.optional_approval_reports }

    where(:existing_comment, :expected) do
      nil | []
      build_comment(optional_approvals: %w[scan_finding]) | %w[scan_finding]
      build_comment(optional_approvals: %w[scan_finding license_scanning]) | %w[scan_finding license_scanning]
      build_comment(optional_approvals: %w[scan_finding invalid]) | %w[scan_finding]
      build(:note, note: "invalid format") | []
    end

    with_them do
      it { is_expected.to match_array(expected) }
    end
  end

  describe '#add_report_type' do
    subject(:add_report_type) { comment.add_report_type(report_type, requires_approval) }

    where(:report_type, :requires_approval, :existing_comment, :expected_reports, :expected_optional_reports) do
      'scan_finding' | true | nil | %w[scan_finding] | []
      'scan_finding' | false | nil | %w[scan_finding] | %w[scan_finding]
      'scan_finding' | true | build_comment(reports: %w[scan_finding]) | %w[scan_finding] | []
      'scan_finding' | false | build_comment(reports: %w[scan_finding]) | %w[scan_finding] | %w[scan_finding]
      'scan_finding' | true | build_comment(reports: %w[license_scanning]) | %w[scan_finding license_scanning] | []
      'scan_finding' | false | build_comment(reports: %w[license_scanning]) | %w[scan_finding
        license_scanning] | %w[scan_finding]
      'scan_finding' | false | build_comment(optional_approvals: %w[license_scanning]) | %w[scan_finding] | %w[
        license_scanning scan_finding
      ]
      'invalid' | true | build_comment(reports: %w[license_scanning]) | %w[license_scanning] | []
      'invalid' | false | build_comment(reports: %w[license_scanning],
        optional_approvals: %w[license_scanning]) | %w[license_scanning] | %w[license_scanning]
    end

    before do
      add_report_type
    end

    with_them do
      it { expect(comment.reports).to match_array(expected_reports) }
      it { expect(comment.optional_approval_reports).to match_array(expected_optional_reports) }
    end
  end

  describe '#remove_report_type' do
    subject(:remove_report_type) { comment.remove_report_type(report_type) }

    where(:report_type, :existing_comment, :expected_reports, :expected_optional_reports) do
      'scan_finding' | nil | [] | []
      'scan_finding' | build_comment(reports: %w[scan_finding]) | [] | []
      'scan_finding' | build_comment(reports: %w[scan_finding], optional_approvals: %w[scan_finding]) | [] | []
      'scan_finding' | build_comment(reports: %w[license_scanning]) | %w[license_scanning] | []
      'scan_finding' | build_comment(reports: %w[license_scanning],
        optional_approvals: %w[license_scanning]) | %w[license_scanning] | %w[license_scanning]
    end

    before do
      remove_report_type
    end

    with_them do
      it { expect(comment.reports).to match_array(expected_reports) }
      it { expect(comment.optional_approval_reports).to match_array(expected_optional_reports) }
    end
  end

  describe '#clear_report_types' do
    subject(:clear_report_types) { comment.clear_report_types }

    let(:existing_comment) { nil }

    before do
      comment.add_report_type('scan_finding', true)
      comment.add_report_type('license_scanning', false)
    end

    it 'can clear all previously added report types' do
      clear_report_types

      expect(comment.reports).to be_empty
      expect(comment.optional_approval_reports).to be_empty
    end
  end

  describe '#body' do
    subject(:body) { comment.body }

    let_it_be(:violations_resolved) { 'Security policy violations have been resolved.' }
    let_it_be(:violations_title_detailed_body) { 'this merge request has policy violations and errors' }
    let_it_be(:unblock_mr_text) { 'To unblock this merge request, fix these items' }

    context 'without reports' do
      it { is_expected.to include violations_resolved }
    end

    context 'with reports' do
      let(:report_requires_approval) { true }

      before do
        comment.add_report_type('scan_finding', report_requires_approval)
      end

      describe 'summary' do
        let_it_be(:policy1) { create(:scan_result_policy_read, project: project) }
        let_it_be(:policy2) { create(:scan_result_policy_read, project: project) }
        let_it_be(:policy3) { create(:scan_result_policy_read, project: project) }
        let_it_be(:scan_finding_rule_policy1) do
          create(:report_approver_rule, :scan_finding, merge_request: merge_request,
            scan_result_policy_read: policy1, name: 'Scan')
        end

        let_it_be(:license_scanning_rule_policy2) do
          create(:report_approver_rule, :license_scanning, merge_request: merge_request,
            scan_result_policy_read: policy2, name: 'License')
        end

        let_it_be(:non_violated_rule_policy3) do
          create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
            scan_result_policy_read: policy3, name: 'Any merge request')
        end

        before do
          create(:scan_result_policy_violation, project: project, merge_request: merge_request,
            scan_result_policy_read: policy1)
          create(:scan_result_policy_violation, project: project, merge_request: merge_request,
            scan_result_policy_read: policy2,
            violation_data: { 'violations' => { 'license_scanning' => { 'MIT' => ['A'] } } })
        end

        it { is_expected.to include violations_title_detailed_body }
        it { is_expected.to include unblock_mr_text }

        context 'when approvals are optional' do
          let(:report_requires_approval) { false }

          it { is_expected.not_to include unblock_mr_text }
          it { is_expected.to include 'Consider including optional reviewers' }
        end

        it { is_expected.to include 'Resolve all violations' }

        it 'includes violated policy names' do
          expect(body)
            .to include 'Resolve all violations in the following merge request approval policies: License, Scan'
          expect(body).not_to include 'Any merge request'
        end

        it 'includes a bullet point for licenses' do
          expect(body)
            .to include('Remove all denied licenses identified by the following merge request approval policies: ' \
              'License')
        end

        context 'with "any_merge_request" rule violations' do
          before do
            create(:scan_result_policy_violation, project: project, merge_request: merge_request,
              scan_result_policy_read: policy3)
          end

          it 'includes information about acquiring approvals' do
            expect(body).to include('Resolve all violations in the following merge request approval policies: ' \
              'Any merge request, License, Scan')
            expect(body).to include('Acquire approvals from eligible approvers defined in the following ' \
              'merge request approval policies: Any merge request')
          end
        end

        context 'with errors' do
          before do
            create(:scan_result_policy_violation, project: project, merge_request: merge_request,
              scan_result_policy_read: policy3, violation_data: { 'errors' => [{ 'error' => 'error' }] })
          end

          it 'includes information about errors' do
            expect(body).to include 'Resolve the errors and re-run the pipeline'
          end
        end

        context 'with fail-open policies' do
          before do
            create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
              scan_result_policy_read: policy3, violation_data: { 'errors' => [{ 'error' => 'SCAN_REMOVED' }] })
          end

          it 'includes information about fail-open policies' do
            expect(body).to include 'The following policies enforced on your project were skipped because they are ' \
              'configured to fail open: Any merge request.'
          end
        end
      end

      context 'without violation details' do
        it { is_expected.not_to include described_class::VIOLATIONS_BLOCKING_TITLE }
        it { is_expected.not_to include described_class::VIOLATIONS_DETECTED_TITLE }
      end

      context 'with violation details' do
        let_it_be(:uuid) { SecureRandom.uuid }
        let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }
        let_it_be(:pipeline) do
          create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
            ref: merge_request.source_branch, sha: merge_request.diff_head_sha,
            merge_requests_as_head_pipeline: [merge_request])
        end

        let_it_be(:ci_build) { pipeline.builds.first }
        let_it_be(:policy) do
          create(:scan_result_policy_read, project: project,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration)
        end

        before_all do
          pipeline_scan = create(:security_scan, :succeeded, build: ci_build, scan_type: 'dependency_scanning')
          create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner, severity: 'high',
            uuid: uuid)
          create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner, uuid: uuid,
            name: 'AWS API key')
        end

        def build_violation_details(report_type, data, policy_read: policy, name: 'Policy', policy_rule: nil)
          project_rule = create(:approval_project_rule, project: project, scan_result_policy_read: policy_read)
          create(:report_approver_rule, report_type, merge_request: merge_request, approval_project_rule: project_rule,
            scan_result_policy_read: policy_read, name: name)
          create(:scan_result_policy_violation, project: project, merge_request: merge_request,
            scan_result_policy_read: policy_read, violation_data: data, approval_policy_rule: policy_rule)
        end

        it { is_expected.not_to include described_class::VIOLATIONS_BLOCKING_TITLE }
        it { is_expected.not_to include described_class::VIOLATIONS_DETECTED_TITLE }

        shared_examples_for 'title for detected violations' do
          it { is_expected.to include described_class::VIOLATIONS_BLOCKING_TITLE }
          it { is_expected.not_to include described_class::VIOLATIONS_DETECTED_TITLE }

          context 'when approvals are optional' do
            let(:report_requires_approval) { false }

            it { is_expected.not_to include described_class::VIOLATIONS_BLOCKING_TITLE }
            it { is_expected.to include described_class::VIOLATIONS_DETECTED_TITLE }
          end
        end

        describe 'newly_introduced_violations' do
          before do
            build_violation_details(:scan_finding,
              {
                context: { pipeline_ids: [pipeline.id] },
                violations: { scan_finding: { uuids: { newly_detected: [uuid] } } }
              })
          end

          it_behaves_like 'title for detected violations'

          it { is_expected.to include 'High', 'Test finding', 'Dependency scanning' }
        end

        describe 'previously_existing_violations' do
          before do
            build_violation_details(:scan_finding,
              {
                violations: { scan_finding: { uuids: { previously_existing: [uuid] } } }
              })
          end

          it_behaves_like 'title for detected violations'

          it { is_expected.to include 'Critical', 'AWS API key', 'Secret detection' }
        end

        describe 'any_merge_request_violations' do
          before do
            build_violation_details(:any_merge_request,
              {
                violations: { any_merge_request: { commits: commits } }
              })
          end

          context 'with a list of commits' do
            let(:commits) { ['abcd1234'] }

            it_behaves_like 'title for detected violations'

            it 'includes the section and a linked commit' do
              expect(body).to include 'Unsigned commits',
                "[`abcd1234`](#{Gitlab::Routing.url_helpers.project_commit_url(project, 'abcd1234')})"
            end

            it { is_expected.not_to include described_class::MORE_VIOLATIONS_DETECTED }

            context 'when the list is longer than MAX_VIOLATIONS' do
              let(:commits) { (0..Security::ScanResultPolicyViolation::MAX_VIOLATIONS).map { |n| "abcdef0#{n}" } }

              it { is_expected.to include(*commits.first(Security::ScanResultPolicyViolation::MAX_VIOLATIONS)) }
              it { is_expected.to include described_class::MORE_VIOLATIONS_DETECTED }
            end
          end

          context 'with any commits' do
            let(:commits) { true }

            it { is_expected.to include 'Acquire approvals from eligible approvers' }
            it { is_expected.not_to include 'Unsigned commits' }
          end
        end

        describe 'license_scanning_violations' do
          before do
            build_violation_details(:license_scanning,
              {
                violations: { license_scanning: { 'MIT' => %w[A B] } }
              })
          end

          it { is_expected.to include 'Out-of-policy licenses', 'MIT', 'Used by A, B' }
        end

        describe 'errors' do
          before do
            build_violation_details(:scan_finding,
              {
                errors: [{ error: Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing] }]
              })
          end

          it { is_expected.to include 'Errors', 'Pipeline configuration error' }
        end

        describe 'comparison pipelines' do
          let_it_be(:target_pipeline) do
            create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
              ref: merge_request.target_branch, sha: merge_request.diff_head_sha)
          end

          def pipeline_id_with_link(id)
            "[##{id}](#{Gitlab::Routing.url_helpers.project_pipeline_url(project, id)})"
          end

          context 'when pipeline ids of one report_type are present' do
            before do
              build_violation_details(:scan_finding,
                { 'context' => { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [target_pipeline.id] } }
              )
            end

            it 'includes linked pipelines in the body' do
              expect(body).to include 'Comparison pipelines',
                pipeline_id_with_link(pipeline.id),
                pipeline_id_with_link(target_pipeline.id)
            end

            it 'does not render the report_type title' do
              expect(body).not_to include 'Scan finding'
            end
          end

          context 'when pipeline ids from multiple reports are present' do
            let_it_be(:policy2) do
              create(:scan_result_policy_read, project: project,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration)
            end

            before do
              build_violation_details(:scan_finding,
                { 'context' => { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [target_pipeline.id] } }
              )
              build_violation_details(:license_scanning,
                { 'context' => { 'pipeline_ids' => [123], 'target_pipeline_ids' => [456] } },
                policy_read: policy2,
                name: 'Policy 2'
              )
            end

            it 'displays them grouped by report_type, showing the titles' do
              expect(body).to include 'Comparison pipelines', 'Scan finding', 'License scanning',
                pipeline_id_with_link(pipeline.id),
                pipeline_id_with_link(target_pipeline.id),
                pipeline_id_with_link(123),
                pipeline_id_with_link(456)
            end
          end

          context 'when multiple pipeline ids are present' do
            before do
              build_violation_details(:scan_finding,
                { 'context' => {
                  'pipeline_ids' => [pipeline.id, 123456],
                  'target_pipeline_ids' => [target_pipeline.id, 456789]
                } }
              )
            end

            it 'displays them as comma-separated list in the body' do
              expect(body).to include 'Comparison pipelines',
                "#{pipeline_id_with_link(pipeline.id)}, #{pipeline_id_with_link(123456)}",
                "#{pipeline_id_with_link(target_pipeline.id)}, #{pipeline_id_with_link(456789)}"
            end
          end

          context 'when some pipeline ids are missing' do
            before do
              build_violation_details(:scan_finding,
                { 'context' => { 'target_pipeline_ids' => [target_pipeline.id] } }
              )
            end

            it 'shows fallback message' do
              expect(body).to include 'Comparison pipelines',
                pipeline_id_with_link(target_pipeline.id),
                "Source branch (`#{merge_request.source_branch}`): None"
            end
          end

          context 'when no pipeline ids are present' do
            it 'does not show comparison pipelines block' do
              expect(body).not_to include 'Comparison pipelines'
            end
          end
        end

        describe '#additional_info' do
          subject(:body) { comment.body }

          let(:warn_mode_db_policy) do
            create(:security_policy, :warn_mode, policy_index: 0,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          context 'when there are no warn mode policies' do
            before do
              build_violation_details(:any_merge_request, { violations: { any_merge_request: { commits: true } } })
            end

            it 'does not include the section' do
              expect(body).not_to include('Additional information')
            end
          end

          context 'when there are warn mode policies' do
            let_it_be(:warn_mode_policy_read) do
              create(:scan_result_policy_read, project: project,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration)
            end

            let_it_be(:warn_mode_db_policy) do
              create(:security_policy, :warn_mode, policy_index: 0,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration)
            end

            let_it_be(:warn_mode_policy_rule) do
              create(:approval_policy_rule, security_policy: warn_mode_db_policy)
            end

            let_it_be(:project_2) { create(:project, :repository) }

            let_it_be(:security_orchestration_policy_configuration_2) do
              create(:security_orchestration_policy_configuration, project: project_2)
            end

            let_it_be(:warn_mode_policy_read_2) do
              create(:scan_result_policy_read, project: project_2,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration_2)
            end

            let_it_be(:warn_mode_db_policy_2) do
              create(:security_policy, :warn_mode, policy_index: 0,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration_2)
            end

            let_it_be(:warn_mode_policy_rule_2) do
              create(:approval_policy_rule, security_policy: warn_mode_db_policy)
            end

            context 'when there is one warn mode policy' do
              before do
                build_violation_details(:any_merge_request, { violations: { any_merge_request: { commits: true } } },
                  policy_read: warn_mode_policy_read, policy_rule: warn_mode_policy_rule)
              end

              it 'includes information about warn mode policies' do
                expect(body).to include('Additional information')
                expect(body).to include(
                  'Review the following policies to understand requirements and identify policy owners for support:')
                expect(body).to include(
                  "[#{warn_mode_policy_rule.security_policy.name}](#{warn_mode_policy_rule.security_policy.edit_path})"
                )
              end
            end

            context 'when there are multiple warn mode policies' do
              before do
                build_violation_details(:any_merge_request, { violations: { any_merge_request: { commits: true } } },
                  policy_read: warn_mode_policy_read, policy_rule: warn_mode_policy_rule)
                build_violation_details(:any_merge_request, { violations: { any_merge_request: { commits: true } } },
                  policy_read: warn_mode_policy_read_2, policy_rule: warn_mode_policy_rule_2, name: 'Policy 2')
              end

              it 'includes information about warn mode policies' do
                expect(body).to include('Additional information')
                expect(body).to include(
                  'Review the following policies to understand requirements and identify policy owners for support:')
                expect(body).to include(
                  "[#{warn_mode_policy_rule.security_policy.name}](#{warn_mode_policy_rule.security_policy.edit_path})",
                  "[#{warn_mode_policy_rule_2.security_policy.name}]" \
                    "(#{warn_mode_policy_rule_2.security_policy.edit_path})"
                )
              end
            end

            context 'when the feature flag is disabled' do
              before do
                stub_feature_flags(security_policy_approval_warn_mode: false)
              end

              it 'does not include the section' do
                expect(body).not_to include('Additional information')
              end
            end
          end
        end
      end
    end
  end
end
