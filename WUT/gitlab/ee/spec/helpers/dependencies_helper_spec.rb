# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependenciesHelper, feature_category: :dependency_management do
  shared_examples 'a helper method that returns shared dependencies data' do
    it 'returns data shared between all views' do
      is_expected.to include(
        has_dependencies: 'false',
        documentation_path: a_string_including("user/application_security/dependency_list/_index"),
        empty_state_svg_path: match(%r{illustrations/empty-state/empty-radar-md.*\.svg})
      )
    end
  end

  describe '#project_dependencies_data' do
    let_it_be(:project) { build_stubbed(:project) }
    let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project) }

    let(:expected_sbom_reports_errors) { "[]" }
    let(:expectations) do
      {
        endpoint: "/#{project.full_path}/-/dependencies.json",
        licenses_endpoint: "/#{project.full_path}/-/dependencies/licenses",
        export_endpoint: "/api/v4/projects/#{project.id}/dependency_list_exports",
        vulnerabilities_endpoint: "/api/v4/occurrences/vulnerabilities",
        sbom_reports_errors: expected_sbom_reports_errors,
        latest_successful_scan_path: "/#{project.full_path}/-/pipelines/#{pipeline.id}",
        scan_finished_at: pipeline.finished_at
      }
    end

    subject { helper.project_dependencies_data(project) }

    before do
      allow(project).to receive(:latest_ingested_sbom_pipeline).and_return(pipeline)
    end

    it_behaves_like 'a helper method that returns shared dependencies data'

    it 'returns the exepected data' do
      is_expected.to include(**expectations)
    end

    context 'with sbom reports errors' do
      let(:sbom_errors) { [["Unsupported CycloneDX spec version. Must be one of: 1.4, 1.5"]] }
      let(:expected_sbom_reports_errors) { sbom_errors.to_json }

      before do
        allow(pipeline).to receive(:sbom_report_ingestion_errors).and_return(sbom_errors)
      end

      it { is_expected.to include(**expectations) }
    end

    context 'when project does not have an sbom pipeline' do
      let_it_be(:pipeline) { nil }

      it 'returns nil values for pipeline keys' do
        is_expected.to include(
          latest_successful_scan_path: nil,
          scan_finished_at: nil
        )
      end
    end
  end

  describe '#group_dependencies_data' do
    let_it_be(:group) { build_stubbed(:group, traversal_ids: [1]) }

    subject { helper.group_dependencies_data(group) }

    it_behaves_like 'a helper method that returns shared dependencies data'

    it 'returns the expected data' do
      is_expected.to include(
        endpoint: "/groups/#{group.full_path}/-/dependencies.json",
        licenses_endpoint: "/groups/#{group.full_path}/-/dependencies/licenses",
        locations_endpoint: "/groups/#{group.full_path}/-/dependencies/locations",
        export_endpoint: "/api/v4/groups/#{group.id}/dependency_list_exports",
        vulnerabilities_endpoint: "/api/v4/occurrences/vulnerabilities"
      )
    end
  end

  describe '#explore_dependencies_data' do
    let_it_be(:organization) { build_stubbed(:organization) }
    let(:page_info) do
      {
        type: 'cursor',
        has_next_page: true,
        has_previous_page: false,
        start_cursor: nil,
        current_cursor: 'current_cursor',
        end_cursor: 'next_page_cursor'
      }
    end

    subject { helper.explore_dependencies_data(organization, page_info) }

    it_behaves_like 'a helper method that returns shared dependencies data'

    it 'returns the expected data' do
      is_expected.to include(
        page_info: page_info,
        endpoint: "/explore/dependencies.json",
        licenses_endpoint: nil,
        locations_endpoint: nil,
        export_endpoint: "/api/v4/organizations/#{organization.id}/dependency_list_exports",
        vulnerabilities_endpoint: nil
      )
    end
  end

  describe '#dependencies_exportable_link' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:url_builder) { Gitlab::UrlBuilder.instance }

    subject(:exportable_link) { helper.dependencies_exportable_link(export) }

    context 'when exportable is a project' do
      let(:project) { build_stubbed(:project) }
      let(:export) { build_stubbed(:dependency_list_export, project: project) }

      it { is_expected.to eq("project <a href=\"#{url_builder.project_url(project)}\">#{project.full_name}</a>") }
    end

    context 'when exportable is a group' do
      let(:group) { build_stubbed(:group) }
      let(:export) { build_stubbed(:dependency_list_export, group: group, project: nil) }

      it { is_expected.to eq("group <a href=\"#{url_builder.group_canonical_url(group)}\">#{group.full_name}</a>") }
    end

    context 'when exportable is an organization' do
      let(:organization) { build_stubbed(:organization) }
      let(:export) { build_stubbed(:dependency_list_export, organization: organization, project: nil) }

      it 'returns the correct link text' do
        url = url_builder.organization_url(organization)
        is_expected.to eq("organization <a href=\"#{url}\">#{organization.name}</a>")
      end
    end

    context 'when exportable is a pipeline' do
      let(:pipeline) { build_stubbed(:ci_pipeline) }
      let(:export) { build_stubbed(:dependency_list_export, pipeline: pipeline, project: pipeline.project) }

      it 'returns correct link text' do
        url = url_builder.project_pipeline_url(pipeline.project, pipeline)
        is_expected.to eq("pipeline <a href=\"#{url}\">##{pipeline.id}</a>")
      end
    end
  end
end
