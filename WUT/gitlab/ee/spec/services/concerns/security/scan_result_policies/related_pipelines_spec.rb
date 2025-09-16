# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::RelatedPipelines, feature_category: :security_policy_management do
  let_it_be(:target_branch) { 'main' }
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be_with_refind(:merge_request) do
    create(:merge_request, :with_merge_request_pipeline, source_project: project)
  end

  let(:class_instance) { subject_class.new }

  let(:subject_class) do
    Class.new do
      include Security::ScanResultPolicies::RelatedPipelines
    end
  end

  describe '#related_pipeline_sources' do
    let(:expected_sources) { Enums::Ci::Pipeline.ci_and_security_orchestration_sources.values }

    subject(:related_pipeline_sources) { subject_class.new.related_pipeline_sources }

    it 'returns the related pipeline sources' do
      expect(related_pipeline_sources).to eq(expected_sources)
    end
  end

  describe '#target_pipeline_for_merge_request' do
    subject(:target_pipeline) { subject_class.new.target_pipeline_for_merge_request(merge_request, report_type) }

    before do
      merge_request.update_head_pipeline
    end

    [:scan_finding, :license_scanning].each do |report_type|
      context "when report_type is #{report_type}" do
        let_it_be(:report_type) { report_type }
        let_it_be(:pipeline_report_type) do
          report_type == :scan_finding ? :with_dependency_scanning_report : :with_cyclonedx_report
        end

        context 'when there is no pipeline on target branch' do
          it 'returns nil' do
            expect(target_pipeline).to be_nil
          end
        end

        context 'when there are pipelines on target branch' do
          context 'when there are pipelines with the expected report type' do
            let_it_be(:pipeline) do
              create(:ee_ci_pipeline, :success,
                pipeline_report_type,
                project: project,
                ref: merge_request.target_branch,
                sha: merge_request.diff_base_sha
              )
            end

            let_it_be(:latest_pipeline) do
              create(:ee_ci_pipeline, :success,
                pipeline_report_type,
                project: project,
                ref: merge_request.target_branch,
                sha: merge_request.diff_base_sha
              )
            end

            it 'returns the latest pipeline on the target branch with the expected report type' do
              expect(target_pipeline).to eq(latest_pipeline)
            end

            context 'when there is a most recent pipeline without the expected report type' do
              let_it_be(:pipeline_without_security_report) do
                create(:ee_ci_pipeline, :success,
                  project: project,
                  ref: merge_request.target_branch,
                  sha: merge_request.diff_base_sha
                )
              end

              it 'returns the latest pipeline on the target branch with the expected report type' do
                expect(target_pipeline).to eq(latest_pipeline)
              end
            end
          end

          context 'when there is no pipeline with the expected report type on the target branch' do
            let_it_be(:pipeline) do
              create(:ee_ci_pipeline, :success,
                project: project,
                ref: merge_request.target_branch,
                sha: merge_request.diff_base_sha
              )
            end

            it 'returns the latest pipeline on the target branch' do
              expect(target_pipeline).to eq(pipeline)
            end
          end
        end
      end
    end
  end

  describe '#related_target_pipeline_ids_for_merge_request' do
    let(:report_type) { :scan_finding }

    subject(:related_target_pipeline_ids) do
      subject_class.new.related_target_pipeline_ids_for_merge_request(merge_request, report_type)
    end

    context 'when there is no pipeline on target branch' do
      it 'returns an empty array' do
        expect(related_target_pipeline_ids).to be_empty
      end
    end

    context 'when there are related pipelines on target branch' do
      let_it_be(:pipeline) do
        create(:ee_ci_pipeline, :success,
          :with_dependency_scanning_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_head_sha
        )
      end

      let_it_be(:another_pipeline) do
        create(:ee_ci_pipeline, :success,
          :with_dependency_scanning_report,
          project: project,
          source: Enums::Ci::Pipeline.sources[:security_orchestration_policy],
          ref: merge_request.target_branch,
          sha: merge_request.diff_head_sha
        )
      end

      it 'returns the related target pipeline ids' do
        expect(related_target_pipeline_ids).to match_array([pipeline.id, another_pipeline.id])
      end
    end
  end

  shared_context 'with related pipelines' do
    let_it_be(:pipeline) do
      create(:ee_ci_pipeline, :success,
        :with_dependency_scanning_report,
        project: project,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha,
        merge_requests_as_head_pipeline: [merge_request]
      )
    end

    let_it_be(:another_pipeline) do
      create(:ee_ci_pipeline, :success,
        :with_dependency_scanning_report,
        project: project,
        source: Enums::Ci::Pipeline.sources[:security_orchestration_policy],
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha
      )
    end

    let_it_be(:unrelated_pipeline) do
      create(:ee_ci_pipeline, :success,
        project: project,
        source: Enums::Ci::Pipeline.sources[:ondemand_dast_scan],
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha
      )
    end
  end

  describe '#related_pipeline_ids' do
    include_context 'with related pipelines'

    let(:pipeline) { merge_request.diff_head_pipeline }

    subject(:related_pipeline_ids) { subject_class.new.related_pipeline_ids(pipeline) }

    it 'returns the related pipeline ids' do
      expect(related_pipeline_ids).to match_array([pipeline.id, another_pipeline.id])
    end

    context 'when pipeline is nil' do
      let(:pipeline) { nil }

      it 'returns empty array' do
        expect(related_pipeline_ids).to be_empty
      end
    end
  end

  describe '#related_pipelines' do
    include_context 'with related pipelines'

    let(:pipeline) { merge_request.diff_head_pipeline }

    subject(:related_pipelines) { subject_class.new.related_pipelines(pipeline) }

    it 'returns the related pipeline ids' do
      expect(related_pipelines).to match_array([pipeline, another_pipeline])
    end

    context 'when pipeline is nil' do
      let(:pipeline) { nil }

      it 'returns empty collection' do
        expect(related_pipelines).to eq(Ci::Pipeline.none)
      end
    end
  end
end
