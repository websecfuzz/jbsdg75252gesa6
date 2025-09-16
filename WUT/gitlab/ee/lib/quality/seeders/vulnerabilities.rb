# frozen_string_literal: true
module Quality
  module Seeders
    class Vulnerabilities
      attr_reader :project

      def initialize(project)
        @project = project
      end

      def seed!
        if author.nil?
          print 'Skipping this project because it has no users'
          return
        end

        30.times do |rank|
          primary_identifier = create_identifier(rank)
          finding = create_finding(rank, primary_identifier)
          vulnerability = create_vulnerability(finding: finding)
          # Create occurrence_identifier join models
          finding.identifiers << primary_identifier
          finding.identifiers << create_identifier(rank) if rank % 3 == 0

          case rank % 3
          when 0
            create_feedback(finding, 'dismissal')
          when 1
            create_feedback(finding, 'issue', vulnerability: vulnerability)
          end

          print '.'
        end
      end

      private

      def create_vulnerability(finding:)
        state_symbol = ::Vulnerability.states.keys.sample.to_sym
        vulnerability = build_vulnerability(state_symbol)
        vulnerability.finding_id = finding.id

        case state_symbol
        when :resolved
          vulnerability.resolved_by = author
        when :dismissed
          vulnerability.dismissed_by = author
        end

        vulnerability.tap(&:save!)
      end

      def build_vulnerability(state_symbol)
        FactoryBot.build(
          :vulnerability,
          state_symbol,
          project: project,
          author: author,
          title: 'Cypher with no integrity',
          severity: random_severity_level,
          report_type: random_report_type
        )
      end

      def create_finding(rank, primary_identifier)
        scanner = FactoryBot.create(:vulnerabilities_scanner, project: project)

        FactoryBot.create(
          :vulnerabilities_finding,
          :with_pipeline,
          project: project,
          scanner: scanner,
          severity: random_severity_level,
          primary_identifier: primary_identifier,
          location_fingerprint: random_fingerprint,
          raw_metadata: Gitlab::Json.dump(metadata(rank))
        )
      end

      def create_identifier(rank)
        FactoryBot.create(
          :vulnerabilities_identifier,
          external_type: "SECURITY_ID",
          external_id: "SECURITY_#{rank}",
          fingerprint: random_fingerprint,
          name: "SECURITY_IDENTIFIER #{rank}",
          url: "https://security.example.com/#{rank}",
          project: project
        )
      end

      def create_feedback(finding, type, vulnerability: nil)
        if type == 'issue'
          issue = create_issue("Dismiss #{finding.name}")
          create_vulnerability_issue_link(vulnerability, issue)
        end

        FactoryBot.create(
          :vulnerability_feedback,
          feedback_type: type,
          project: project,
          author: author,
          issue: issue,
          pipeline: pipeline
        )
      end

      def create_issue(title)
        FactoryBot.create(
          :issue,
          project: project,
          author: author,
          title: title
        )
      end

      def create_vulnerability_issue_link(vulnerability, issue)
        FactoryBot.create(
          :vulnerabilities_issue_link,
          :created,
          vulnerability: vulnerability,
          issue: issue
        )
      end

      def random_severity_level
        ::Enums::Vulnerability.severity_levels.keys.sample
      end

      def random_report_type
        ::Enums::Vulnerability.report_types.keys.sample
      end

      def metadata(line)
        {
          description: "The cipher does not provide data integrity update 1",
          solution: "GCM mode introduces an HMAC into the resulting encrypted data, providing integrity of the result.",
          location: {
            file: "maven/src/main/java//App.java",
            start_line: line,
            end_line: line,
            class: "com.gitlab..App",
            method: "insecureCypher"
          },
          links: [
            {
              name: "Cipher does not check for integrity first?",
              url: "https://crypto.stackexchange.com/questions/31428/pbewithmd5anddes-cipher-does-not-check-for-integrity-first"
            }
          ]
        }
      end

      def random_fingerprint
        SecureRandom.hex(20)
      end

      def pipeline
        @pipeline ||= project.ci_pipelines.where(ref: project.default_branch).last # rubocop:disable CodeReuse/ActiveRecord
      end

      def author
        @author ||= project.users.first
      end
    end
  end
end
