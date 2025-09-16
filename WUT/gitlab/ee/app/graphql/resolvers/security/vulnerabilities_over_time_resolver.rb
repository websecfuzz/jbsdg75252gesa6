# frozen_string_literal: true

module Resolvers
  module Security
    class VulnerabilitiesOverTimeResolver < VulnerabilitiesBaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      MAX_DATE_RANGE_DAYS = 1.year.in_days.floor.freeze

      type Types::Security::VulnerabilitiesOverTimeType.connection_type, null: true

      authorize :read_security_resource

      argument :start_date, GraphQL::Types::ISO8601Date,
        required: true,
        description: 'Start date for the vulnerability metrics time range.'

      argument :end_date, GraphQL::Types::ISO8601Date,
        required: true,
        description: 'End date for the vulnerability metrics time range.'

      def resolve(start_date:, end_date:, **args)
        authorize!(object) unless resolve_vulnerabilities_for_instance_security_dashboard?

        validate_date_range!(start_date, end_date)

        return [] if !vulnerable || Feature.disabled?(:group_security_dashboard_new, vulnerable)
        return [] unless Feature.enabled?(:group_security_dashboard_new, vulnerable)

        project_id = args[:project_id]
        severity = args[:severity]
        scanner = args[:scanner]

        generate_dummy_data(start_date, end_date, project_id: project_id, severity: severity, scanner: scanner)
      end

      private

      def validate_date_range!(start_date, end_date)
        raise Gitlab::Graphql::Errors::ArgumentError, "start date cannot be after end date" if start_date > end_date

        return unless (end_date - start_date) > MAX_DATE_RANGE_DAYS

        raise Gitlab::Graphql::Errors::ArgumentError, "maximum date range is #{MAX_DATE_RANGE_DAYS} days"
      end

      # rubocop: disable Lint/UnusedMethodArgument -- to do
      def generate_dummy_data(start_date, end_date, project_id: nil, severity: nil, scanner: nil)
        # rubocop: enable Lint/UnusedMethodArgument
        # project_id to be done in future MR
        (start_date..end_date).map do |current_date|
          total_count = rand(20..50)

          severity_counts = [
            { "count" => rand(1..5), "severity" => "critical" },
            { "count" => rand(3..8), "severity" => "high" },
            { "count" => rand(5..15), "severity" => "medium" },
            { "count" => rand(10..20), "severity" => "low" },
            { "count" => rand(0..3), "severity" => "unknown" }
          ]

          severity_counts = severity_counts.select { |s| severity.include?(s["severity"]) } if severity.present?

          report_type_counts = [
            { "count" => rand(5..15), "report_type" => "sast" },
            { "count" => rand(3..10), "report_type" => "dast" },
            { "count" => rand(2..8), "report_type" => "dependency_scanning" },
            { "count" => rand(1..5), "report_type" => "container_scanning" },
            { "count" => rand(0..3), "report_type" => "secret_detection" }
          ]

          if scanner.present?
            report_type_counts = report_type_counts.select do |s|
              scanner.include?(s["report_type"])
            end
          end

          {
            "date" => current_date,
            "count" => total_count,
            :by_severity => severity_counts,
            :by_report_type => report_type_counts
          }
        end
      end
    end
  end
end
