# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::LicenseViolationChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }

  let(:case5) do
    [
      ['GPL v3', 'GNU 3', 'A'],
      ['MIT', 'MIT License', 'B'],
      ['GPL v3', 'GNU 3', 'C'],
      ['Apache 2', 'Apache License 2', 'D']
    ]
  end

  let(:case4) { [['GPL v3', 'GNU 3', 'A'], ['MIT', 'MIT License', 'B'], ['GPL v3', 'GNU 3', 'C']] }
  let(:case3) { [['GPL v3', 'GNU 3', 'A'], ['MIT', 'MIT License', 'B']] }
  let(:case2) { [['GPL v3', 'GNU 3', 'A']] }
  let(:case1) { [] }

  let(:license_name_spdx_map) { { 'GNU 3' => 'GPL v3', 'MIT License' => 'MIT' } }

  describe 'possible combinations' do
    using RSpec::Parameterized::TableSyntax

    let(:violation1) { { 'GNU 3' => %w[A] } }
    let(:violation2) { { 'GNU 3' => %w[A C] } }
    let(:violation3) { { 'GNU 3' => %w[C] } }
    let(:violation4) { { 'Apache License 2' => %w[D] } }

    subject(:service) { described_class.new(project, pipeline_report, target_branch_report) }

    context 'with software_licenses' do
      include_context 'for license_checker'

      with_them do
        let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
        let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

        let(:match_on_inclusion_license) { policy_state == :denied }
        let(:license_states) { states }
        let(:license_name) { policy_license[1] }
        let(:scan_result_policy_read) do
          create(:scan_result_policy_read, project: project, license_states: license_states,
            match_on_inclusion_license: match_on_inclusion_license)
        end

        before do
          target_branch.each do |ld|
            target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
          end

          pipeline_branch.each do |ld|
            pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
          end

          create(:software_license_policy, policy_state,
            project: project,
            scan_result_policy_read: scan_result_policy_read,
            software_license_spdx_identifier: license_name_spdx_map[license_name]
          )
        end

        it 'syncs approvals_required' do
          result = service.execute(scan_result_policy_read)

          expect(result).to eq(violated_licenses)
        end
      end
    end

    context 'with custom_software_licenses' do
      include_context 'for license_checker'

      with_them do
        let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
        let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

        let(:match_on_inclusion_license) { policy_state == :denied }
        let(:license_states) { states }

        let(:custom_license) { create(:custom_software_license, name: policy_license[1]) }
        let(:scan_result_policy_read) do
          create(:scan_result_policy_read, project: project, license_states: license_states,
            match_on_inclusion_license: match_on_inclusion_license)
        end

        before do
          target_branch.each do |ld|
            target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
          end

          pipeline_branch.each do |ld|
            pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
          end

          create(:software_license_policy, policy_state,
            project: project,
            custom_software_license: custom_license,
            software_license_spdx_identifier: nil,
            scan_result_policy_read: scan_result_policy_read
          )
        end

        subject(:service_result) { service.execute(scan_result_policy_read) }

        it 'syncs approvals_required' do
          expect(service_result).to eq(violated_licenses)
        end
      end

      context 'with software licenses and custom_software_licenses' do
        include_context 'for license_checker'

        with_them do
          let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
          let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

          let(:match_on_inclusion_license) { policy_state == :denied }
          let(:license_states) { states }

          let(:license) do
            if policy_license[0].present?
              create(:software_license, spdx_identifier: policy_license[0], name: policy_license[1])
            else
              create(:custom_software_license, name: policy_license[1])
            end
          end

          let(:scan_result_policy_read) do
            create(:scan_result_policy_read, project: project, license_states: license_states,
              match_on_inclusion_license: match_on_inclusion_license)
          end

          before do
            target_branch.each do |ld|
              target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
            end

            pipeline_branch.each do |ld|
              pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
            end

            if license.is_a?(SoftwareLicense)
              create(:software_license_policy, policy_state,
                project: project,
                custom_software_license: nil,
                scan_result_policy_read: scan_result_policy_read,
                software_license_spdx_identifier: policy_license[0]
              )
            else
              create(:software_license_policy, policy_state,
                project: project,
                custom_software_license: license,
                software_license_spdx_identifier: nil,
                scan_result_policy_read: scan_result_policy_read
              )
            end
          end

          it 'syncs approvals_required' do
            result = service.execute(scan_result_policy_read)

            expect(result).to eq(violated_licenses)
          end
        end
      end
    end
  end
end
