# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.mergeRequest.findingReportsComparer', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let(:mock_report) do
    {
      status: :parsed,
      status_reason: 'An example reason',
      data: {
        base_report_out_of_date: false,
        base_report_created_at: nil,
        head_report_created_at: Time.now.to_s,
        added: [
          {
            uuid: SecureRandom.uuid,
            name: 'Test Vulnerability',
            description: 'Test description',
            severity: 'critical',
            state: 'confirmed',
            scanner: {
              name: 'Semgrep',
              external_id: 'semgrep',
              vendor: 'Semgrep Inc.'
            },
            found_by_pipeline: {
              iid: 1
            },
            report_type: 'sast', # necessary for mocking location type correctly
            location: {
              file: 'foo.js',
              start_line: '1',
              end_line: nil
            },
            identifiers: [
              {
                external_type: 'semgrep_id',
                external_id: 'eslint.detect-disable-mustache-escape',
                name: 'eslint.detect-disable-mustache-escape',
                url: 'https://semgrep.dev/r/gitlab.eslint.detect-disable-mustache-escape'
              }
            ],
            blob_path: '/foo.js#L1',
            details: {
              code_flows: {
                name: 'code_flows',
                type: 'code-flows',
                items: [
                  [
                    {
                      type: 'code-flow-node',
                      node_type: 'source',
                      file_location: {
                        type: 'file-location',
                        file_name: 'path/to/file/app.py',
                        line_start: 8,
                        line_end: 8
                      }
                    },
                    {
                      type: 'code-flow-node',
                      node_type: 'propagation',
                      file_location: {
                        type: 'file-location',
                        file_name: 'path/to/file/app.py',
                        line_start: 4,
                        line_end: 4
                      }
                    },
                    {
                      type: 'code-flow-node',
                      node_type: 'sink',
                      file_location: {
                        type: 'file-location',
                        file_name: 'path/to/file/utils.py',
                        line_start: 5,
                        line_end: 5
                      }
                    }
                  ]
                ]
              }
            }
          }
        ],
        fixed: []
      }.deep_stringify_keys
    }
  end

  let(:finding_reports_comparer_fields) do
    <<~QUERY
      findingReportsComparer(reportType: SAST) {
        status
        statusReason
        report {
          baseReportCreatedAt
          headReportCreatedAt
          baseReportOutOfDate
          added {
            uuid
            title
            description
            severity
            state
            scanner {
              name
              externalId
              vendor
            }
            foundByPipelineIid
            location {
              ...on VulnerabilityLocationSast {
                file
                startLine
                endLine
                blobPath
              }
            }
            identifiers {
              externalType
              externalId
              name
              url
            }
            details {
              ... on VulnerabilityDetailCodeFlows {
                name
                items {
                  ... {
                    ... on VulnerabilityDetailCodeFlowNode {
                      nodeType
                      fileLocation {
                        ... on VulnerabilityDetailFileLocation {
                          lineEnd
                          lineStart
                          fileName
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          fixed {
            uuid
            title
            description
            severity
            state
            scanner {
              name
              externalId
              vendor
            }
            foundByPipelineIid
            location {
              ...on VulnerabilityLocationSast {
                file
                startLine
                endLine
                blobPath
              }
            }
            identifiers {
              externalType
              externalId
              name
              url
            }
          }
        }
      }
    QUERY
  end

  let(:merge_request_fields) do
    query_graphql_field(
      :merge_request,
      { iid: merge_request.iid.to_s },
      finding_reports_comparer_fields)
  end

  let(:query) { graphql_query_for(:project, { full_path: project.full_path }, merge_request_fields) }

  subject(:result) { graphql_data_at(:project, :merge_request, :finding_reports_comparer) }

  before do
    allow(::Security::MergeRequestSecurityReportGenerationService).to receive(:execute).and_return(mock_report)
  end

  context 'when the user is not authorized to read the field' do
    before do
      post_graphql(query, current_user: user)
    end

    it { is_expected.to be_nil }
  end

  context 'when the user is authorized to read the field' do
    before do
      stub_licensed_features(security_dashboard: true)

      project.add_developer(user)

      post_graphql(query, current_user: user)
    end

    it 'returns expected data' do
      expect(result).to match(a_hash_including(
        {
          status: 'PARSED',
          statusReason: 'An example reason',
          report: {
            baseReportOutOfDate: false,
            baseReportCreatedAt: nil,
            headReportCreatedAt: an_instance_of(String),
            added: [
              {
                uuid: an_instance_of(String),
                title: 'Test Vulnerability',
                description: 'Test description',
                severity: 'CRITICAL',
                state: 'CONFIRMED',
                scanner: {
                  name: 'Semgrep',
                  externalId: 'semgrep',
                  vendor: 'Semgrep Inc.'
                },
                foundByPipelineIid: '1',
                location: {
                  endLine: nil,
                  file: 'foo.js',
                  startLine: '1',
                  blobPath: '/foo.js#L1'
                },
                identifiers: [
                  {
                    externalId: 'eslint.detect-disable-mustache-escape',
                    externalType: 'semgrep_id',
                    name: 'eslint.detect-disable-mustache-escape',
                    url: 'https://semgrep.dev/r/gitlab.eslint.detect-disable-mustache-escape'
                  }
                ],
                details: [
                  {
                    name: 'code_flows',
                    items: [
                      [
                        {
                          nodeType: 'SOURCE',
                          fileLocation: {
                            fileName: 'path/to/file/app.py',
                            lineStart: 8,
                            lineEnd: 8
                          }
                        },
                        {
                          nodeType: 'PROPAGATION',
                          fileLocation: {
                            fileName: 'path/to/file/app.py',
                            lineStart: 4,
                            lineEnd: 4
                          }
                        },
                        {
                          nodeType: 'SINK',
                          fileLocation: {
                            fileName: 'path/to/file/utils.py',
                            lineStart: 5,
                            lineEnd: 5
                          }
                        }
                      ]
                    ]
                  }
                ]
              }
            ],
            fixed: []
          }
        }.deep_stringify_keys))
    end
  end
end
