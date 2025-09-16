# frozen_string_literal: true

# This service track executions of a Secure analyzer scan using Snowplow.
#
# @param build [Ci::Build] the build that ran the scan.
module Security
  class TrackScanService
    SECURE_SCAN_SCHEMA_URL = 'iglu:com.gitlab/secure_scan/jsonschema/1-1-0'

    def initialize(build)
      @build = build
    end

    def execute
      build.unmerged_security_reports.reports.each { |report_type, report| track_scan_event(report_type, report) }
    rescue Gitlab::Ci::Parsers::Security::Common::SecurityReportParserError
      nil
    end

    private

    attr_reader :build

    def track_scan_event(report_type, report)
      context = SnowplowTracker::SelfDescribingJson.new(SECURE_SCAN_SCHEMA_URL, data_to_track(report_type, report))

      idempotency_key = [build.project_id, build.id, scan_type(report, report_type), report&.scan&.start_time || ""].join("::")

      ::Gitlab::Tracking.event(
        'secure::scan',
        'scan',
        context: [context],
        idempotency_key: Digest::SHA256.hexdigest(idempotency_key),
        user: build.user,
        project: build.project_id,
        label: analyzer_id(report),
        property: scan_type(report, report_type)
      )
    end

    def data_to_track(report_type, report)
      analyzer = report&.analyzer
      scan = report&.scan
      scanner = report&.scanner
      findings = report&.findings || []

      {
        analyzer: analyzer_id(report),
        analyzer_vendor: analyzer&.vendor,
        analyzer_version: analyzer&.version,
        findings_count: findings.count,
        end_time: scan&.end_time,
        report_schema_version: report&.version,
        scan_type: scan_type(report, report_type),
        scanner: scanner&.external_id,
        scanner_vendor: scanner&.vendor,
        scanner_version: scanner&.version,
        start_time: scan&.start_time,
        status: scan&.status || 'success'
      }
    end

    def scan_type(report, report_type)
      report&.scan&.type || report_type
    end

    def analyzer_id(report)
      report&.analyzer&.id
    end
  end
end
