# frozen_string_literal: true

module Sbom
  class MergeReportsService
    attr_reader :merged_report, :reports

    def initialize(reports)
      @reports = reports
    end

    def execute
      all_tools = Set.new
      all_authors = Set.new
      all_properties = Set.new
      all_components = Set.new

      reports.each do |report|
        all_tools.merge(convert_tools(report.metadata.tools))
        all_authors.merge report.metadata.authors
        all_properties.merge report.metadata.properties
        all_components.merge(sbom_components_for(report))
      end

      merged_report = ::Gitlab::Ci::Reports::Sbom::Report.new
      merged_report.metadata.timestamp = Time.current.as_json
      merged_report.metadata.tools = all_tools.to_a
      merged_report.metadata.authors = all_authors.to_a
      merged_report.metadata.properties = all_properties.to_a
      merged_report.components = all_components.to_a

      merged_report
    end

    private

    def sbom_components_for(report)
      component_with_licenses_for(report).map do |component|
        component.type = 'library'
        component.purl = "pkg:#{component.purl_type}/#{component.name}@#{component.version}"

        component
      end
    end

    def component_with_licenses_for(report)
      ::Gitlab::LicenseScanning::PackageLicenses.new(components: report.components).fetch
    end

    def convert_tools(tools)
      return [] unless tools

      if tools.is_a? Array
        tools
      else
        tools&.deep_symbolize_keys&.fetch(:components, [])&.map { |e| convert_tool_into_deprecated_form(e) }
      end
    end

    # Spec 1.4 of CycloneDX requires the old tool object structure
    def convert_tool_into_deprecated_form(tool)
      {
        vendor: tool[:group],
        name: tool[:name],
        version: tool[:version]
      }
    end
  end
end
