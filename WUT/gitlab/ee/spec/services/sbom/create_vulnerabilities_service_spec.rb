# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::CreateVulnerabilitiesService, feature_category: :software_composition_analysis do
  describe '.execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:pipeline) { create(:ee_ci_pipeline, user: user) }
    let_it_be(:project) { pipeline.project }
    let_it_be(:scanner) { create(:vulnerabilities_scanner, :sbom_scanner, project: project) }
    let(:occurrences_count) { 5 }
    let(:sbom_reports) { pipeline.sbom_reports.reports.select(&:source) }
    let(:pipeline_components) { sbom_reports.flat_map(&:components) }
    let(:occurrences) do
      components = sbom_report.components
      Array.new(occurrences_count) do |i|
        { purl_type: components[i].purl.type, name: components[i].name, version: components[i].version,
          input_file_path: sbom_report.source.input_file_path }
      end
    end

    let(:sbom_report) { pipeline.sbom_reports.reports.last }
    let(:source) { sbom_report.source }
    let(:ci_build) { build(:ee_ci_build, :cyclonedx, pipeline: pipeline, project: project) }
    let(:occurrence) { occurrences.first }
    let(:known_affected_range) { "<9999" }

    subject(:result) { described_class.execute(pipeline.id) }

    before do
      pipeline.builds << ci_build
      pipeline.save!
    end

    def sanitized_distro_version(source)
      "#{source.operating_system_name} #{source.operating_system_version&.gsub(/\.\d$/, '')}"
    end

    shared_examples 'creates vulnerabilities related to occurrences' do
      it 'creates vulnerabilities for each advisory' do
        result

        expected_vulnerability_attributes = affected_packages.map do |affected_package|
          expected_report_type = if Enums::Sbom.dependency_scanning_purl_type?(affected_package.purl_type)
                                   'dependency_scanning'
                                 else
                                   'container_scanning'
                                 end

          have_attributes(
            author_id: user.id,
            project_id: project.id,
            state: 'detected',
            report_type: expected_report_type,
            present_on_default_branch: true,
            title: affected_package.advisory.title,
            severity: affected_package.advisory.cvss_v3.severity.downcase,
            finding_description: affected_package.advisory.description,
            solution: affected_package.solution)
        end

        expect(Vulnerability.all).to match_array(expected_vulnerability_attributes)
      end
    end

    shared_examples 'when an existing vulnerability is missing from the report' do |report_type|
      let(:report_type) { report_type }

      context 'when it has a matching report type' do
        let(:finding) { create(:vulnerabilities_finding, scanner: scanner, project: project) }
        let(:vulnerability) do
          create(:vulnerability, findings: [finding], project: project,
            report_type: report_type)
        end

        it 'marks vulnerability as no longer detected' do
          expect { result }.to change { vulnerability.reload.resolved_on_default_branch }.to(true)
        end
      end

      context 'when it does not have a matching report type' do
        let(:finding) { create(:vulnerabilities_finding, scanner: scanner, project: project) }
        let(:vulnerability) do
          create(:vulnerability, findings: [finding], project: project,
            report_type: :container_scanning_for_registry)
        end

        it 'does not mark vulnerability as no longer detected' do
          expect { result }.not_to change { vulnerability.reload.resolved_on_default_branch }.from(false)
        end
      end
    end

    it { expect { result }.not_to change { Vulnerability.count } }

    context 'with affected packages matching name and purl_type only' do
      before do
        create(:pm_affected_package, purl_type: occurrence[:purl_type], package_name: occurrence[:name])
      end

      it { expect { result }.not_to change { Vulnerability.count } }
    end

    context 'with affected packages matching name purl_type and version' do
      let!(:affected_packages) do
        occurrences.map do |occurrence|
          create(:pm_affected_package, purl_type: occurrence[:purl_type], package_name: occurrence[:name],
            affected_range: known_affected_range, distro_version: sanitized_distro_version(source))
        end
      end

      context 'with existing vulnerability' do
        let_it_be_with_reload(:vulnerability) do
          create(:vulnerability, :with_scanner, scanner: scanner, project: project, report_type: :dependency_scanning)
        end

        it_behaves_like 'when an existing vulnerability is missing from the report', :dependency_scanning
      end

      it 'tracks internal metrics with the right parameters', :freeze_time do
        expect { result }.to trigger_internal_events('cvs_on_sbom_change')
          .with(
            project: pipeline.project,
            additional_properties:
              {
                label: 'pipeline_info',
                property: pipeline.id.to_s,
                start_time: Time.current.iso8601,
                end_time: Time.current.iso8601,
                possibly_affected_sbom_occurrences: pipeline_components.count,
                known_affected_sbom_occurrences: occurrences.count,
                sbom_occurrences_semver_dialects_errors_count: 0
              }
          )
      end

      include_examples 'creates vulnerabilities related to occurrences'

      context 'with multiple affected packages with different advisories associated with a single occurrence' do
        before do
          create(:pm_affected_package, purl_type: occurrence[:purl_type],
            package_name: occurrence[:name], affected_range: ">=#{occurrence[:version]}")
        end

        it 'creates vulnerability related to both affected packages in relation to the first occurrence' do
          expect { result }.to change { Vulnerability.count }.by(occurrences_count + 1)
        end
      end

      context 'with existing related vulnerability findings' do
        before do
          affected_package = affected_packages[0]
          location = ::Gitlab::Ci::Reports::Security::Locations::DependencyScanning.new(
            file_path: occurrence[:input_file_path],
            package_name: occurrence[:name],
            package_version: occurrence[:version]
          )
          identifier = ::Gitlab::Ci::Reports::Security::Identifier.new(
            external_type: "gemnasium",
            external_id: affected_package.advisory.advisory_xid,
            name: nil,
            url: nil)

          primary_identifier = create(:vulnerabilities_identifier, fingerprint: identifier.fingerprint)
          create(:vulnerabilities_finding,
            report_type: :dependency_scanning,
            project_id: pipeline.project.id,
            primary_identifier: primary_identifier,
            location_fingerprint: location.fingerprint)
        end

        it 'does not created new vulnerability findings' do
          expect { result }.to change { Vulnerabilities::Finding.count }.by(occurrences_count - 1)
        end
      end

      context 'with container scanning sbom reports' do
        let(:ci_build) do
          build(:ee_ci_build, :cyclonedx_container_scanning, pipeline: pipeline, project: pipeline.project)
        end

        include_examples 'creates vulnerabilities related to occurrences'

        context 'with cvs_for_container_scanning feature flag disabled' do
          before do
            stub_feature_flags(cvs_for_container_scanning: false)
          end

          it 'does not create vulnerabilities' do
            expect { result }.not_to change { Vulnerability.count }
          end
        end
      end

      context 'with container scanning and dependency scanning reports' do
        let(:container_scanning_ci_build) do
          build(:ee_ci_build, :cyclonedx_container_scanning)
        end

        let(:dependency_scanning_ci_build) do
          build(:ee_ci_build, :cyclonedx)
        end

        let(:pipeline) do
          create(:ee_ci_pipeline, user: user, builds: [container_scanning_ci_build, dependency_scanning_ci_build])
        end

        let(:project) { pipeline.project }

        let(:sbom_reports) { pipeline.sbom_reports.reports.select(&:source) }

        let(:container_scanning_sbom_report) do
          sbom_reports.find { |report| report.source&.source_type == :container_scanning }
        end

        let(:container_scanning_source) { container_scanning_sbom_report.source }

        let(:dependency_scanning_sbom_report) do
          sbom_reports.find { |report| report.source&.source_type == :dependency_scanning }
        end

        let(:container_scanning_components) do
          sbom_reports
            .filter { |report| report.source&.source_type == :container_scanning }
            .flat_map(&:components)
        end

        let(:dependency_scanning_components) do
          sbom_reports
            .filter { |report| report.source&.source_type == :dependency_scanning }
            .flat_map(&:components)
        end

        let(:container_scanning_occurrences) do
          container_scanning_components.take(occurrences_count).map do |component|
            { purl_type: component.purl.type, name: component.name, version: component.version }
          end
        end

        let(:dependency_scanning_occurrences) do
          dependency_scanning_components.take(occurrences_count).map do |component|
            { purl_type: component.purl.type, name: component.name, version: component.version,
              input_file_path: dependency_scanning_sbom_report.source.input_file_path }
          end
        end

        let(:container_scanning_affected_packages) do
          container_scanning_occurrences.map do |occurrence|
            create(:pm_affected_package, purl_type: occurrence[:purl_type], package_name: occurrence[:name],
              affected_range: known_affected_range,
              distro_version: sanitized_distro_version(container_scanning_source))
          end
        end

        let(:dependency_scanning_affected_packages) do
          dependency_scanning_occurrences.map do |occurrence|
            create(:pm_affected_package, purl_type: occurrence[:purl_type], package_name: occurrence[:name],
              affected_range: known_affected_range)
          end
        end

        let(:scanner) { create(:vulnerabilities_scanner, :sbom_scanner, project: project) }

        let(:affected_packages) { container_scanning_affected_packages + dependency_scanning_affected_packages }

        include_examples 'creates vulnerabilities related to occurrences'
        include_examples 'when an existing vulnerability is missing from the report', :dependency_scanning
        include_examples 'when an existing vulnerability is missing from the report', :container_scanning
      end

      context 'when any SemverDialect:Error is raised' do
        before do
          create(:pm_affected_package, purl_type: occurrence[:purl_type],
            package_name: occurrence[:name], affected_range: ">=3.0.0alpha <= 3.8.2 || <= 2.15.0")
        end

        include_examples 'creates vulnerabilities related to occurrences'

        it 'captures the error and tracks internal metrics with the right parameters', :freeze_time do
          expect { result }.to trigger_internal_events('cvs_on_sbom_change')
            .with(
              project: pipeline.project,
              additional_properties:
                {
                  label: 'pipeline_info',
                  property: pipeline.id.to_s,
                  start_time: Time.current.iso8601,
                  end_time: Time.current.iso8601,
                  possibly_affected_sbom_occurrences: pipeline_components.count,
                  known_affected_sbom_occurrences: occurrences.count,
                  sbom_occurrences_semver_dialects_errors_count: 1
                }
            )
        end
      end
    end
  end
end
