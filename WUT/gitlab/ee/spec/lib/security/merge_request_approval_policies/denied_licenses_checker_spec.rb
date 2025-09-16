# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::MergeRequestApprovalPolicies::DeniedLicensesChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
  let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }
  let_it_be(:approval_policy_rule) { nil }
  let(:service) do
    described_class.new(project, pipeline_report, target_branch_report, scan_result_policy_read,
      approval_policy_rule)
  end

  subject(:denied_licenses_with_dependencies) { service.denied_licenses_with_dependencies }

  shared_examples_for 'tracks enforce_approval_policies_with_package_exceptions_in_project event' do
    # rubocop:disable Layout/LineLength -- easier to read in single line
    it 'tracks internal metrics with the right parameters', :clean_gitlab_redis_shared_state do
      expect do
        denied_licenses_with_dependencies
      end
        .to trigger_internal_events('enforce_approval_policies_with_package_exceptions_in_project')
          .with(project: project,
            additional_properties: { label: policy_state == :denied ? 'denylist' : 'allowlist' })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_namespace_id_from_enforce_approval_policies_with_package_exceptions_in_project_monthly',
            'redis_hll_counters.count_distinct_namespace_id_from_enforce_approval_policies_with_package_exceptions_in_project_weekly',
            'redis_hll_counters.count_distinct_project_id_from_enforce_approval_policies_with_package_exceptions_in_project_monthly',
            'redis_hll_counters.count_distinct_project_id_from_enforce_approval_policies_with_package_exceptions_in_project_weekly',
            'counts.count_total_enforce_approval_policies_with_package_exceptions_in_project_monthly',
            'counts.count_total_enforce_approval_policies_with_package_exceptions_in_project_weekly',
            'counts.count_total_enforce_approval_policies_with_package_exceptions_in_project'
          )
    end
    # rubocop:enable Layout/LineLength
  end

  context 'without package exceptions' do
    include_context 'for denied_licenses_checker without package exceptions'

    with_them do
      let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
      let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }
      let(:license_states) { states }
      let(:licenses) { { policy_state.to_sym => [{ name: policy_license }] } }

      let(:scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          license_states: license_states,
          licenses: licenses
        )
      end

      before do
        target_branch_licenses.each do |ld|
          target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
        end

        pipeline_branch_licenses.each do |ld|
          pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
        end
      end

      it 'returns denied_licenses_with_dependencies' do
        is_expected.to eq(violated_licenses)
      end

      it_behaves_like 'tracks enforce_approval_policies_with_package_exceptions_in_project event'
    end
  end

  context 'with package exceptions' do
    shared_examples_for 'with package exceptions' do
      include_context 'for denied_licenses_checker with package exceptions'

      with_them do
        let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
        let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }
        let(:license_states) { states }
        let(:licenses) do
          { policy_state.to_sym => [{ name: policy_license, packages: { excluding: { purls: excluded_packages } } }] }
        end

        let(:scan_result_policy_read) do
          create(:scan_result_policy_read,
            project: project,
            license_states: license_states,
            licenses: licenses
          )
        end

        let(:approval_policy_rule_content) do
          {
            type: 'license_finding',
            branches: [],
            license_states: license_states,
            licenses: licenses
          }
        end

        let(:approval_policy_rule) do
          create(:approval_policy_rule, :license_finding_with_allowed_licenses,
            content: approval_policy_rule_content)
        end

        before do
          target_branch_licenses.each do |ld|
            target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(purl_type: ld[2], name: ld[3],
              version: ld[4])
          end

          pipeline_branch_licenses.each do |ld|
            pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(purl_type: ld[2], name: ld[3],
              version: ld[4])
          end
        end

        it 'returns denied_licenses_with_dependencies' do
          is_expected.to eq(violated_licenses)
        end

        it_behaves_like 'tracks enforce_approval_policies_with_package_exceptions_in_project event'
      end
    end

    it_behaves_like 'with package exceptions'
  end
end
