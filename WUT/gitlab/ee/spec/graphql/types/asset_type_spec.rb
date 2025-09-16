# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AssetType'] do
  let_it_be(:project) { create(:project) }
  let(:fields) do
    %i[name type url]
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ee_ci_pipeline, :with_api_fuzzing_report, project: project) }

  let_it_be(:build_1) { create(:ci_build, :success, name: 'dependency_scanning', pipeline: pipeline) }
  let_it_be(:build_2) { create(:ci_build, :success, name: 'sast', pipeline: pipeline) }
  let_it_be(:artifact_ds) { create(:ee_ci_job_artifact, :dependency_scanning, job: build_1) }
  let_it_be(:artifact_sast) { create(:ee_ci_job_artifact, :sast, job: build_2) }
  let_it_be(:report_ds) { create(:ci_reports_security_report, pipeline: pipeline, type: :dependency_scanning) }
  let_it_be(:report_sast) { create(:ci_reports_security_report, pipeline: pipeline, type: :sast) }

  before_all do
    ds_content = File.read(artifact_ds.file.path)
    Gitlab::Ci::Parsers::Security::DependencyScanning.parse!(ds_content, report_ds)
    report_ds.merge!(report_ds)
    sast_content = File.read(artifact_sast.file.path)
    Gitlab::Ci::Parsers::Security::Sast.parse!(sast_content, report_sast)
    report_sast.merge!(report_sast)

    findings = { artifact_ds => report_ds, artifact_sast => report_sast }.flat_map do |artifact, report|
      scan = create(:security_scan, :latest_successful, scan_type: artifact.job.name, build: artifact.job)
      scanner_external_id = report.scanner.external_id
      scanner = create(:vulnerabilities_scanner, project: pipeline.project, external_id: scanner_external_id)

      report.findings.collect do |finding|
        create(
          :security_finding,
          :with_finding_data,
          severity: finding.severity,
          uuid: finding.uuid,
          deduplicated: true,
          scan: scan,
          scanner: scanner
        )
      end
    end

    findings.second.update!(deduplicated: false)
  end

  before do
    stub_licensed_features(api_fuzzing: true, security_dashboard: true)

    project.add_developer(user)
  end

  subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

  specify { expect(described_class.graphql_name).to eq('AssetType') }

  it { expect(described_class).to have_graphql_fields(fields) }

  describe 'checking field contents' do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            pipeline(iid: "#{pipeline.iid}") {
              securityReportFindings {
                nodes {
                  title
                  assets {
                    name
                    type
                    url
                  }
                }
              }
            }
          }
        }
      )
    end

    it 'checks the contents of the assets field' do
      vulnerabilities = subject.dig('data', 'project', 'pipeline', 'securityReportFindings', 'nodes')

      asset = vulnerabilities.first['assets'].first

      expect(asset).to eq({
        "name" => "Test Postman Collection",
        "type" => "postman",
        "url" => "http://localhost/test.collection"
      })
    end
  end
end
