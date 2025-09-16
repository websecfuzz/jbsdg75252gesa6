# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CompareSecurityReportsService, :clean_gitlab_redis_shared_state, feature_category: :vulnerability_management do
  subject { service.execute(base_pipeline, head_pipeline) }

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { project.owner }
  let_it_be(:test_pipelines) do
    {
      default_base: create(:ee_ci_pipeline),
      with_dependency_scanning_report: create(:ee_ci_pipeline, :with_dependency_scanning_report, project: project),
      with_container_scanning_report: create(:ee_ci_pipeline, :with_container_scanning_report, project: project),
      with_dast_report: create(:ee_ci_pipeline, :with_dast_report, project: project),
      with_sast_report: create(:ee_ci_pipeline, :with_sast_report, project: project),
      with_secret_detection_report: create(:ee_ci_pipeline, :with_secret_detection_report, project: project),
      with_dependency_scanning_feature_branch: create(:ee_ci_pipeline, :with_dependency_scanning_feature_branch, project: project),
      with_container_scanning_feature_branch: create(:ee_ci_pipeline, :with_container_scanning_feature_branch, project: project),
      with_dast_feature_branch: create(:ee_ci_pipeline, :with_dast_feature_branch, project: project),
      with_sast_feature_branch: create(:ee_ci_pipeline, :with_sast_feature_branch, project: project),
      with_secret_detection_feature_branch: create(:ee_ci_pipeline, :with_secret_detection_feature_branch, project: project),
      with_corrupted_dependency_scanning_report: create(:ee_ci_pipeline, :with_corrupted_dependency_scanning_report, project: project),
      with_corrupted_container_scanning_report: create(:ee_ci_pipeline, :with_corrupted_container_scanning_report, project: project)
    }
  end

  let(:service) { described_class.new(project, current_user, report_type: scan_type.to_s) }

  def create_scan_with_findings(scan_type, pipeline, count = 1)
    scan = create(
      :security_scan,
      :latest_successful,
      project: project,
      pipeline: pipeline,
      scan_type: scan_type
    )

    create_list(
      :security_finding,
      count,
      :with_finding_data,
      deduplicated: true,
      scan: scan
    )
  end

  before_all do
    create_scan_with_findings('dependency_scanning', test_pipelines[:with_dependency_scanning_report], 4)
    create_scan_with_findings('container_scanning', test_pipelines[:with_container_scanning_report], 8)
    create_scan_with_findings('dast', test_pipelines[:with_dast_report], 20)
    create_scan_with_findings('sast', test_pipelines[:with_sast_report], 5)
    create_scan_with_findings('secret_detection', test_pipelines[:with_secret_detection_report])
    create_scan_with_findings('dependency_scanning', test_pipelines[:with_dependency_scanning_feature_branch], 4)
    create_scan_with_findings('container_scanning', test_pipelines[:with_container_scanning_feature_branch], 8)
    create_scan_with_findings('dast', test_pipelines[:with_dast_feature_branch], 20)
    create_scan_with_findings('sast', test_pipelines[:with_sast_feature_branch], 5)
    create_scan_with_findings('secret_detection', test_pipelines[:with_secret_detection_feature_branch])
  end

  shared_examples_for 'serializes `found_by_pipeline` attribute' do
    let(:first_added_finding) { subject.dig(:data, 'added').first }
    let(:first_fixed_finding) { subject.dig(:data, 'fixed').first }

    it 'sets correct `found_by_pipeline` attribute' do
      expect(first_added_finding.dig('found_by_pipeline', 'iid')).to eq(head_pipeline.iid)
      expect(first_fixed_finding.dig('found_by_pipeline', 'iid')).to eq(base_pipeline.iid)
    end
  end

  shared_examples_for 'when only the head pipeline has a report' do
    let(:base_pipeline) { test_pipelines[:default_base] }
    let(:head_pipeline) { test_pipelines[:"with_#{scan_type}_report"] }

    it 'reports the new vulnerabilities, while not changing the counts of fixed vulnerabilities' do
      expect(subject[:status]).to eq(:parsed)
      expect(subject[:data]['added'].count).to eq(num_findings_in_fixture)
      expect(subject[:data]['fixed'].count).to eq(0)
    end
  end

  shared_examples_for 'when base and head pipelines have scanning reports' do
    let_it_be(:base_pipeline) { test_pipelines[:"with_#{scan_type}_report"] }
    let_it_be(:head_pipeline) { test_pipelines[:"with_#{scan_type}_feature_branch"] }
    let(:expected_payload_fields) do
      %w[create_vulnerability_feedback_issue_path create_vulnerability_feedback_merge_request_path
        create_vulnerability_feedback_dismissal_path]
    end

    it 'reports status as parsed' do
      expect(subject[:status]).to eq(:parsed)
    end

    it 'populates fields based on current_user' do
      payload = subject[:data]['added'].first
      expected_payload_fields.each { |f| expect(payload[f]).to be_present }
      expect(service.current_user).to eq(current_user)
    end

    it 'reports added vulnerabilities' do
      expect(subject[:data]['added'].size).to eq(num_added_findings)
    end

    it 'reports fixed vulnerabilities' do
      expect(subject[:data]['fixed'].size).to eq(num_fixed_findings)
    end
  end

  shared_examples_for 'when head pipeline has corrupted scanning reports' do
    let_it_be(:base_pipeline) { test_pipelines[:"with_corrupted_#{scan_type}_report"] }
    let_it_be(:head_pipeline) { test_pipelines[:"with_corrupted_#{scan_type}_report"] }

    it 'returns status and error message' do
      expect(subject[:status]).to eq(:error)
      expect(subject[:status_reason]).to include('JSON parsing failed')
    end

    it 'returns status and error message when pipeline is nil' do
      result = service.execute(nil, head_pipeline)

      expect(result[:status]).to eq(:error)
      expect(result[:status_reason]).to include('JSON parsing failed')
    end
  end

  shared_examples_for 'when a pipeline has scan that is not in the `succeeded` state' do
    let_it_be(:base_pipeline) { test_pipelines[:default_base] }
    let_it_be(:head_pipeline) { test_pipelines[:"with_#{scan_type}_feature_branch"] }

    let_it_be(:incomplete_scan) do
      create(
        :security_scan,
        build: head_pipeline.builds.last,
        status: :created,
        scan_type: scan_type
      )
    end

    it 'reports status as parsing' do
      expect(subject[:status]).to eq(:parsing)
    end

    it 'has the parsing payload' do
      payload = subject[:key]
      expect(payload).to include(base_pipeline.id, head_pipeline.id)
    end

    context 'when the transitioning cache key exists' do
      before do
        described_class.set_security_mr_widget_to_polling(pipeline_id: base_pipeline.id)
        described_class.set_security_mr_widget_to_polling(pipeline_id: head_pipeline.id)
      end

      it 'reports status as parsing' do
        expect(subject[:status]).to eq(:parsing)
      end

      it 'does not query the database' do
        expect { subject }.not_to make_queries_matching(/SELECT 1 AS one/)
      end

      context 'when report type cache key exists' do
        before do
          described_class.set_security_report_type_to_ready(pipeline_id: base_pipeline.id, report_type: scan_type)
          described_class.set_security_report_type_to_ready(pipeline_id: head_pipeline.id, report_type: scan_type)
        end

        it 'reports status as parsed' do
          expect(subject[:status]).to eq(:parsed)
        end

        it 'does not query the database' do
          expect { subject }.not_to make_queries_matching(/SELECT 1 AS one/)
        end
      end
    end
  end

  describe '.transition_cache_key' do
    subject { described_class.transition_cache_key(pipeline_id: pipeline.id) }

    let_it_be(:pipeline) { test_pipelines[:default_base] }

    it { is_expected.to eq("security_mr_widget::report_parsing_check::#{pipeline.id}:transitioning") }

    context 'when pipeline_id is nil' do
      it 'returns nil' do
        expect(described_class.transition_cache_key(pipeline_id: nil)).to be_nil
      end
    end

    context 'when pipeline_id is not present' do
      it 'returns nil' do
        expect(described_class.transition_cache_key(pipeline_id: '')).to be_nil
      end
    end
  end

  describe '.ready_cache_key' do
    subject { described_class.ready_cache_key(pipeline_id: pipeline.id, report_type: 'foo') }

    let_it_be(:pipeline) { test_pipelines[:default_base] }

    it { is_expected.to eq("security_mr_widget::report_parsing_check::foo::#{pipeline.id}") }

    context 'when pipeline_id is nil' do
      it 'returns nil' do
        expect(described_class.ready_cache_key(pipeline_id: nil)).to be_nil
      end
    end

    context 'when pipeline_id is not present' do
      it 'returns nil' do
        expect(described_class.ready_cache_key(pipeline_id: '')).to be_nil
      end
    end
  end

  describe '#execute' do
    before do
      stub_licensed_features(security_dashboard: true, scan_type => true)
    end

    context 'with dependency_scanning' do
      let_it_be(:scan_type) { :dependency_scanning }

      it_behaves_like 'when only the head pipeline has a report' do
        let(:num_findings_in_fixture) { 4 }
      end

      it_behaves_like 'when base and head pipelines have scanning reports' do
        let(:num_fixed_findings) { 4 }
        let(:num_added_findings) { 4 }

        it 'queries the database' do
          expect { subject }.to make_queries_matching(/SELECT 1 AS one/)
        end

        it_behaves_like 'serializes `found_by_pipeline` attribute'
      end

      it_behaves_like 'when a pipeline has scan that is not in the `succeeded` state'
    end

    context 'with container_scanning' do
      let_it_be(:scan_type) { :container_scanning }

      it_behaves_like 'when only the head pipeline has a report' do
        let(:num_findings_in_fixture) { 8 }
      end

      it_behaves_like 'when base and head pipelines have scanning reports' do
        let(:num_fixed_findings) { 8 }
        let(:num_added_findings) { 8 }

        it 'queries the database' do
          expect { subject }.to make_queries_matching(/SELECT 1 AS one/)
        end

        it_behaves_like 'serializes `found_by_pipeline` attribute'
      end

      it_behaves_like 'when a pipeline has scan that is not in the `succeeded` state'
    end

    context 'with dast' do
      let_it_be(:scan_type) { :dast }

      it_behaves_like 'when only the head pipeline has a report' do
        let(:num_findings_in_fixture) { 20 }
      end

      it_behaves_like 'when base and head pipelines have scanning reports' do
        let(:num_fixed_findings) { 20 }
        let(:num_added_findings) { 20 }

        it 'queries the database' do
          expect { subject }.to make_queries_matching(/SELECT 1 AS one/)
        end

        it_behaves_like 'serializes `found_by_pipeline` attribute'
      end

      it_behaves_like 'when a pipeline has scan that is not in the `succeeded` state'
    end

    context 'with sast' do
      let_it_be(:scan_type) { :sast }

      it_behaves_like 'when only the head pipeline has a report' do
        let(:num_findings_in_fixture) { 5 }
      end

      it_behaves_like 'when base and head pipelines have scanning reports' do
        let(:num_fixed_findings) { 5 }
        let(:num_added_findings) { 5 }

        it 'queries the database' do
          expect { subject }.to make_queries_matching(/SELECT 1 AS one/)
        end

        it_behaves_like 'serializes `found_by_pipeline` attribute'
      end

      it_behaves_like 'when a pipeline has scan that is not in the `succeeded` state'
    end

    context 'with secret detection' do
      let_it_be(:scan_type) { :secret_detection }

      it_behaves_like 'when only the head pipeline has a report' do
        let(:num_findings_in_fixture) { 1 }
      end

      it_behaves_like 'when base and head pipelines have scanning reports' do
        let(:num_fixed_findings) { 0 }
        let(:num_added_findings) { 1 }
        let(:expected_payload_fields) { [] }

        it 'queries the database' do
          expect { subject }.to make_queries_matching(/SELECT 1 AS one/)
        end
      end

      it_behaves_like 'when a pipeline has scan that is not in the `succeeded` state'
    end

    describe 'order of findings' do
      let(:head_pipeline) { create(:ee_ci_pipeline, :with_sast_report, project: project) }
      let(:base_pipeline) { test_pipelines[:default_base] }
      let(:scan_type) { 'sast' }

      let(:scan) do
        create(
          :security_scan,
          :latest_successful,
          project: project,
          pipeline: head_pipeline,
          scan_type: scan_type
        )
      end

      let!(:medium_finding) do
        create(
          :security_finding,
          :with_finding_data,
          deduplicated: true,
          severity: Enums::Vulnerability.severity_levels[:medium],
          scan: scan
        )
      end

      let!(:high_finding) do
        create(
          :security_finding,
          :with_finding_data,
          deduplicated: true,
          severity: Enums::Vulnerability.severity_levels[:high],
          scan: scan
        )
      end

      let!(:critical_finding) do
        create(
          :security_finding,
          :with_finding_data,
          deduplicated: true,
          severity: Enums::Vulnerability.severity_levels[:critical],
          scan: scan
        )
      end

      it 'returns findings in decreasing order of severity' do
        added_findings_ids = subject[:data]['added'].pluck("id")

        expect(added_findings_ids[0]).to eq(critical_finding.id)
        expect(added_findings_ids[1]).to eq(high_finding.id)
        expect(added_findings_ids[2]).to eq(medium_finding.id)
      end

      it 'returns findings in decreasing order with no more than MAX_FINDINGS_COUNT findings' do
        stub_const("Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer::MAX_FINDINGS_COUNT", 2)

        added_findings_ids = subject[:data]['added'].pluck("id")

        expect(added_findings_ids.count).to eq(2)
        expect(added_findings_ids[0]).to eq(critical_finding.id)
        expect(added_findings_ids[1]).to eq(high_finding.id)
      end
    end
  end
end
