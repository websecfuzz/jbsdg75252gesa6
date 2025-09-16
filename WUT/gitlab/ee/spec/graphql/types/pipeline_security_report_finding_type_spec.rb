# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PipelineSecurityReportFinding'], feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, id: 12346) }
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, :with_sast_report, project: project) }

  let_it_be(:sast_build) { create(:ci_build, :success, name: 'sast', pipeline: pipeline) }
  let_it_be(:sast_artifact) { create(:ee_ci_job_artifact, :sast, job: sast_build) }
  let_it_be(:sast_report) { create(:ci_reports_security_report, type: :sast, pipeline: pipeline) }
  let_it_be(:sast_scan) { create(:security_scan, :latest_successful, scan_type: :sast, build: sast_artifact.job) }
  let_it_be(:sast_findings) { create_findings(sast_scan, sast_report, sast_artifact) }

  let_it_be(:dep_scan_build) { create(:ci_build, :success, name: 'dependency_scanning', pipeline: pipeline) }
  let_it_be(:dep_scan_artifact) { create(:ee_ci_job_artifact, :dependency_scanning_remediation, job: dep_scan_build) }
  let_it_be(:dep_scan_report) { create(:ci_reports_security_report, type: :dependency_scanning, pipeline: pipeline) }
  let_it_be(:dep_scan_scan) do
    create(:security_scan, :latest_successful, scan_type: :dependency_scanning, build: dep_scan_artifact.job)
  end

  let_it_be(:dep_scan_findings) { create_findings(dep_scan_scan, dep_scan_report, dep_scan_artifact) }

  let(:fields) do
    %i[report_type
      title
      severity
      severity_overrides
      scanner
      identifiers
      links
      assets
      evidence
      uuid
      project
      description
      location
      falsePositive
      solution
      state
      details
      vulnerability
      finding_token_status
      issueLinks
      merge_request
      remediations
      dismissed_at
      dismissed_by
      dismissal_reason
      state_comment
      description_html
      solution_html
      user_permissions
      ai_resolution_available
      ai_resolution_enabled]
  end

  let(:sast_query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          pipeline(iid: "#{pipeline.iid}") {
            securityReportFindings(reportType: ["sast"], state: [CONFIRMED, DETECTED, DISMISSED, RESOLVED]) {
              nodes {
                #{query_for_test}
              }
            }
          }
        }
      }
    )
  end

  let(:dep_scan_query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          pipeline(iid: "#{pipeline.iid}") {
            securityReportFindings(reportType: ["dependency_scanning"]) {
              nodes {
                #{query_for_test}
              }
            }
          }
        }
      }
    )
  end

  before do
    stub_licensed_features(sast: true, dependency_scanning: true, security_dashboard: true, sast_fp_reduction: true)
    project.add_developer(user)
  end

  subject { GitlabSchema.execute(sast_query, context: { current_user: user }).as_json }

  specify { expect(described_class.graphql_name).to eq('PipelineSecurityReportFinding') }
  specify { expect(described_class).to require_graphql_authorizations(:read_security_resource) }

  it { expect(described_class).to have_graphql_fields(fields) }

  describe 'false_positive' do
    let(:query_for_test) do
      %(
        falsePositive
      )
    end

    context 'when the security finding has a false-positive flag' do
      before do
        allow_next_found_instance_of(Security::Finding) do |finding|
          allow(finding).to receive(:false_positive?).and_return(true)
        end
      end

      it 'returns false-positive value' do
        expect(get_findings_from_response(subject).first['falsePositive']).to be(true)
      end
    end

    context 'when the security finding does not have any false-positive flag' do
      it 'returns false for false-positive field' do
        expect(get_findings_from_response(subject).first['falsePositive']).to be(false)
      end
    end

    context 'when there exists no license' do
      before do
        stub_licensed_features(sast: true, security_dashboard: true, sast_fp_reduction: false)
      end

      it 'returns nil for false-positive field' do
        expect(get_findings_from_response(subject).first['falsePositive']).to be_nil
      end
    end
  end

  describe 'vulnerability' do
    let(:query_for_test) do
      %(
        uuid
        vulnerability {
          description
          issueLinks {
            nodes {
              issue {
                description
              }
            }
          }
        }
      )
    end

    it 'returns no vulnerabilities for the security findings when none exists' do
      expect(get_findings_from_response(subject).first['vulnerabilty']).to be_nil
    end

    context 'when the security finding has a related vulnerability' do
      let_it_be(:vulnerability) { create(:vulnerability, :with_issue_links, project: project) }
      let_it_be(:vulnerability_finding) do
        create(:vulnerabilities_finding, project: project, vulnerability: vulnerability, uuid: sast_findings.first.uuid)
      end

      let(:vulnerability_description) { get_findings_from_response(subject).first['vulnerability']['description'] }

      it 'returns vulnerabilities for the security findings' do
        expect(vulnerability_description).to eq(vulnerability.description)
      end

      it 'avoids N+1 queries' do
        # Warm up table schema and other data (e.g. SAML providers, license)
        GitlabSchema.execute(sast_query, context: { current_user: user })

        control = ActiveRecord::QueryRecorder.new { run_with_clean_state(sast_query, context: { current_user: user }) }

        vulnerabilities = get_findings_from_response(subject).pluck('vulnerability').compact
        issues = get_issues_from_vulnerabilities(vulnerabilities)
        expect(vulnerabilities.count).to eq(1)
        expect(issues.count).to eq(2)

        new_vulnerability = create(:vulnerability, :with_issue_links, project: project)
        create(
          :vulnerabilities_finding,
          project: project,
          vulnerability: new_vulnerability,
          uuid: sast_findings.second.uuid
        )

        expect { run_with_clean_state(sast_query, context: { current_user: user }) }
          .not_to exceed_query_limit(control)

        response = GitlabSchema.execute(sast_query, context: { current_user: user })
        vulnerabilities = get_findings_from_response(response).pluck('vulnerability').compact
        issues = get_issues_from_vulnerabilities(vulnerabilities)
        expect(vulnerabilities.count).to eq(2)
        expect(issues.count).to eq(4)
      end
    end
  end

  describe 'issue_links' do
    let(:query_for_test) do
      %(
        uuid
        issueLinks {
          nodes {
            issue {
              description
            }
          }
        }
      )
    end

    it 'returns no issues for the security findings when no vulnerability exists' do
      expect(get_findings_from_response(subject).first['issueLinks']).to be_nil
    end

    context 'when there is a vulnerabillty with no issues' do
      let_it_be(:vulnerability) { create(:vulnerability, project: project) }
      let_it_be(:vulnerability_finding) do
        create(:vulnerabilities_finding, project: project, vulnerability: vulnerability, uuid: sast_findings.first.uuid)
      end

      let(:issue_links) { get_findings_from_response(subject).first['issueLinks']['nodes'] }

      it 'returns no issues' do
        expect(issue_links).to be_empty
      end
    end

    context 'when the security finding has a related vulnerability' do
      let_it_be(:issue) { create(:issue, description: 'Vulnerability issue description', project: project) }
      let_it_be(:vulnerability) { create(:vulnerability, project: project) }
      let_it_be(:vulnerability_finding) do
        create(
          :vulnerabilities_finding,
          project: project,
          vulnerability: vulnerability,
          uuid: sast_findings.first.uuid
        )
      end

      let_it_be(:issue_link) { create(:vulnerabilities_issue_link, vulnerability: vulnerability, issue: issue) }

      let(:issue_description) do
        get_findings_from_response(subject).first['issueLinks']['nodes'].first['issue']['description']
      end

      it 'returns issues for the security findings' do
        expect(issue_description).to eq(issue.description)
      end

      it 'avoids N+1 queries' do
        # Warm up table schema and other data (e.g. SAML providers, license)
        GitlabSchema.execute(sast_query, context: { current_user: user })

        control = ActiveRecord::QueryRecorder.new { run_with_clean_state(sast_query, context: { current_user: user }) }

        findings = get_findings_from_response(subject)
        issues = get_issues_from_findings(findings)
        expect(issues.count).to eq(1)

        new_vulnerability = create(:vulnerability, :with_issue_links, project: project)
        create(
          :vulnerabilities_finding,
          project: project,
          vulnerability: new_vulnerability,
          uuid: sast_findings.second.uuid
        )

        expect { run_with_clean_state(sast_query, context: { current_user: user }) }
          .not_to exceed_query_limit(control)

        response = GitlabSchema.execute(sast_query, context: { current_user: user })
        findings = get_findings_from_response(response)
        issues = get_issues_from_findings(findings)
        expect(issues.count).to eq(3)
      end
    end
  end

  describe 'location' do
    describe 'blob_path' do
      let(:query_for_test) do
        %(
          location {
            ... on VulnerabilityLocationSast { blobPath }
        }
      )
      end

      let(:blob_path_regex) { %r{/#{project.namespace.path}/#{project.path}/-/blob/[a-f0-9]{40}/} }

      context 'when a blob path exists' do
        it 'returns the blob path' do
          blob_paths = graphql_dig_at(subject, :data, :project, :pipeline, :security_report_findings, :nodes, :location)
                         .map { |location| graphql_dig_at(location, :blob_path) }
          expect(blob_paths).to all(match blob_path_regex)
        end
      end
    end
  end

  describe 'merge_request' do
    let(:query_for_test) do
      %(
        uuid
        mergeRequest {
          id
          description
        }
      )
    end

    context 'when a merge request link exists' do
      let!(:initial_query) do
        # Warm up table schema and other data (e.g. SAML providers, license)
        run_with_clean_state(sast_query, context: { current_user: user })

        ActiveRecord::QueryRecorder.new do
          run_with_clean_state(sast_query, context: { current_user: user })
        end
      end

      let_it_be(:vulnerabilities) { create_list(:vulnerability, sast_findings.count, project: project) }
      let_it_be(:merge_requests) do
        create_list(:merge_request, sast_findings.count, :unique_branches, source_project: project)
      end

      let_it_be(:merge_request_links) do
        merge_requests.zip(vulnerabilities).map do |(merge_request, vulnerability)|
          create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
        end
      end

      let_it_be(:vulnerability_findings) do
        vulnerabilities.each_with_index.map do |vulnerability, index|
          create(
            :vulnerabilities_finding,
            project: project,
            vulnerability: vulnerability,
            uuid: sast_findings[index].uuid
          )
        end
      end

      it 'returns the linked merged requests' do
        ids = graphql_dig_at(subject, :data, :project, :pipeline, :security_report_findings, :nodes)
          .filter_map { |node| graphql_dig_at(node, :merge_request, :id) }

        expect(ids).to match_array(merge_requests.map { |mr| mr.to_global_id.to_s })
      end

      it 'prevents N+1' do
        expect do
          run_with_clean_state(sast_query, context: { current_user: user })
        end.not_to exceed_query_limit(initial_query).with_threshold(1)
      end
    end

    context 'when a merge request link does not exist' do
      let_it_be(:vulnerability) { create(:vulnerability, project: project) }
      let_it_be(:vulnerability_finding) do
        create(
          :vulnerabilities_finding,
          project: project,
          vulnerability: vulnerability,
          uuid: sast_findings.first.uuid
        )
      end

      it 'does not return a merge request' do
        nodes = graphql_dig_at(subject, :data, :project, :pipeline, :security_report_findings, :nodes)

        expect(nodes.length).to eq(sast_findings.length)
        expect(nodes.filter_map { |node| graphql_dig_at(node, :merge_request) }).to be_empty
      end
    end

    it 'returns no merge requests for the security findings when no vulnerability finding exists' do
      expect(get_findings_from_response(subject).first['mergeRequest']).to be_nil
    end

    context 'when there is a security finding with no merge request' do
      let_it_be(:vulnerability_finding) do
        create(:vulnerabilities_finding, project: project, uuid: sast_findings.first.uuid)
      end

      it 'returns no merge requests' do
        expect(get_findings_from_response(subject).first['mergeRequest']).to be_nil
      end
    end
  end

  describe 'remediations' do
    let(:response) { GitlabSchema.execute(dep_scan_query, context: { current_user: user }) }
    let(:remediation_finding) { dep_scan_findings.second }
    let(:expected_remediations) { remediation_finding.remediations.map { |r| r.slice('summary', 'diff') } }
    let(:response_remediations) { response_remediation_finding['remediations'] }
    let(:response_remediation_finding) do
      get_findings_from_response(response).find { |finding| finding['uuid'] == remediation_finding.uuid }
    end

    let(:query_for_test) do
      %(
        uuid
        remediations {
          summary
          diff
        }
      )
    end

    before do
      # These offsets will need to be updated if the
      # remediations/gl-dependency-scanning-report.json # fixture is modified.
      #
      # The offsets need to be set to the position of the opening and closing
      # curly braces of the first element of the "remediations" array in
      # the fixture file.
      remediation_finding.finding_data = { remediation_byte_offsets: [{ start_byte: 3730, end_byte: 13753 }] }
      remediation_finding.save!
    end

    it 'returns remediations for security findings which have one' do
      expect(response_remediations).to match(expected_remediations)
    end

    it 'responds with an empty array for security findings which have none' do
      expect(dep_scan_findings.map(&:remediations)).to include([])
    end

    context 'when a remediation does not exist for a single finding query' do
      let(:response) { GitlabSchema.execute(remediations_query, context: { current_user: user }) }
      let(:response_remediation) do
        response.dig('data', 'project', 'pipeline', 'securityReportFinding', 'remediations')
      end

      let(:remediations_query) do
        %(
          query {
            project(fullPath: "#{project.full_path}") {
              pipeline(iid: "#{pipeline.iid}") {
                securityReportFinding(uuid: "#{dep_scan_findings.first.uuid}") {
                  remediations {
                    summary
                    diff
                  }
                }
              }
            }
          }
        )
      end

      context 'when a vulnerability finding exists for the report finding' do
        let_it_be(:vulnerability_finding) do
          create(:vulnerabilities_finding, project: project, uuid: dep_scan_findings.first.uuid)
        end

        it 'responds with an empty array' do
          expect(response_remediation).to be_empty
        end
      end

      context 'when a vulnerability finding does not exist for the report finding' do
        it 'responds with an empty array' do
          expect(response_remediation).to be_empty
        end
      end
    end
  end

  describe 'dismissal data' do
    let(:query_for_test) do
      %(
        uuid
        dismissedAt
        dismissedBy {
          name
        }
        stateComment
        dismissalReason
      )
    end

    context 'when there is a security finding with no dismissal state transition' do
      it 'returns no dismissal data' do
        expect(get_findings_from_response(subject).first['dismissed_at']).to be_nil
      end
    end

    context 'when the security finding has a related dismissal state transition' do
      let_it_be(:sast_vulnerability) do
        create_vulnerability_from_security_finding(project, sast_findings.first)
      end

      let_it_be(:sast_dismissal_transition) do
        create(:vulnerability_state_transition,
          vulnerability: sast_vulnerability,
          from_state: :detected,
          to_state: :dismissed,
          dismissal_reason: :used_in_tests,
          comment: "Sast Test Dismissal",
          author: user
        )
      end

      let(:response_finding) { get_findings_from_response(subject).first }
      let(:expected_response_finding) do
        {
          'uuid' => sast_vulnerability.finding_uuid,
          'dismissedAt' => sast_dismissal_transition.created_at.iso8601,
          'dismissedBy' => { 'name' => sast_dismissal_transition.author.name },
          'stateComment' => sast_dismissal_transition.comment,
          'dismissalReason' => sast_dismissal_transition.dismissal_reason.upcase
        }
      end

      it 'returns the dismissal data for the security findings' do
        expect(response_finding).to eq(expected_response_finding)
      end

      # There is an N+1 query issue.
      # Address this by https://gitlab.com/gitlab-org/gitlab/-/issues/468190
      xit 'avoids N+1 queries' do
        # Warm up table schema and other data (e.g. SAML providers, license)
        run_with_clean_state(sast_query, context: { current_user: user })

        initial_query =
          ActiveRecord::QueryRecorder.new { run_with_clean_state(dep_scan_query, context: { current_user: user }) }

        expect { run_with_clean_state(sast_query, context: { current_user: user }) }
          .not_to exceed_query_limit(initial_query)
      end

      context 'when the number of requested dismissal fields changes' do
        let(:reduced_query) do
          %(
            query {
              project(fullPath: "#{project.full_path}") {
                pipeline(iid: "#{pipeline.iid}") {
                  securityReportFindings(reportType: ["sast"], state: [CONFIRMED, DETECTED, DISMISSED, RESOLVED]) {
                    nodes {
                      uuid
                      dismissedBy {
                        name
                      }
                    }
                  }
                }
              }
            }
          )
        end

        it 'does not increase the number of queries' do
          # Warm up table schema and other data (e.g. SAML providers, license)
          run_with_clean_state(sast_query, context: { current_user: user })

          initial_query =
            ActiveRecord::QueryRecorder.new { run_with_clean_state(reduced_query, context: { current_user: user }) }

          expect { run_with_clean_state(sast_query, context: { current_user: user }) }
            .not_to exceed_query_limit(initial_query)
        end
      end
    end
  end

  describe 'severity_overrides' do
    let(:query_for_test) do
      %(
        uuid
        severityOverrides {
          nodes {
            originalSeverity
            newSeverity
            createdAt
            author {
              name
            }
          }
        }
      )
    end

    it 'returns no records for the security findings when no vulnerability exists' do
      expect(get_findings_from_response(subject).first['severityOverrides']).to be_nil
    end

    context 'when the security finding has a related vulnerability without severity overrides' do
      let_it_be(:vulnerability) { create(:vulnerability, project: project) }
      let_it_be(:vulnerability_finding) do
        create(:vulnerabilities_finding, project: project, vulnerability: vulnerability, uuid: sast_findings.first.uuid)
      end

      let(:severity_overrides) { get_findings_from_response(subject).first['severityOverrides']['nodes'] }

      it 'returns no severity overrides' do
        expect(severity_overrides).to be_empty
      end
    end

    context 'when the security finding has a related vulnerability with severity overrides' do
      let_it_be(:vulnerability) { create(:vulnerability, :with_severity_override, project: project) }
      let_it_be(:vulnerability_finding) do
        create(:vulnerabilities_finding, project: project, vulnerability: vulnerability, uuid: sast_findings.first.uuid)
      end

      let(:severity_override) { get_findings_from_response(subject).first['severityOverrides']['nodes'].first }

      it 'returns severity overrides' do
        expect(severity_override['newSeverity'].capitalize).to eq("Medium")
        expect(severity_override['originalSeverity'].capitalize).to eq(vulnerability.severity.capitalize)
        expect(severity_override['createdAt']).to eq(vulnerability.severity_overrides[0].created_at.utc.iso8601)
      end
    end
  end

  def create_vulnerability_from_security_finding(project, security_finding)
    finding = create(:vulnerabilities_finding, project: project, uuid: security_finding.uuid)
    create(:vulnerability,
      findings: [finding],
      project: project,
      state: :dismissed
    )
  end

  def create_findings(scan, report, artifact)
    content = File.read(artifact.file.path)
    ::Gitlab::Ci::Parsers.parsers[report.type].parse!(content, report)
    report.merge!(report)
    report.findings.map do |finding|
      create(:security_finding, :with_finding_data, uuid: finding.uuid, scan: scan, deduplicated: true,
        location: finding.location_data)
    end
  end

  def get_findings_from_response(response)
    response.dig('data', 'project', 'pipeline', 'securityReportFindings', 'nodes')
  end

  def get_issues_from_findings(findings)
    findings.pluck('issueLinks').compact.pluck('nodes').flatten
  end
  alias_method :get_issues_from_vulnerabilities, :get_issues_from_findings

  def get_merge_requests_from_query
    response = run_with_clean_state(sast_query, context: { current_user: user })
    findings = get_findings_from_response(response)
    findings.pluck('mergeRequest').compact
  end
end
