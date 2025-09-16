# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::CreatePipelineService, :clean_gitlab_redis_shared_state,
  feature_category: :continuous_integration do
  include ProjectForksHelper

  describe '#execute' do
    subject { service.execute(merge_request) }

    let(:service) { described_class.new(project: source_project, current_user: user, params: params) }
    let(:project) { create(:project, :repository) }
    let(:user) { create(:user) }
    let(:params) { {} }
    let(:title) { 'Awesome merge request' }
    let(:merge_pipelines_enabled) { true }
    let(:merge_pipelines_license) { true }
    let(:source_project) { project }
    let(:source_branch) { 'feature' }
    let(:target_project) { project }
    let(:target_branch) { 'master' }

    let(:merge_request) do
      create(:merge_request,
        source_project: source_project, source_branch: source_branch,
        target_project: target_project, target_branch: target_branch,
        merge_status: 'unchecked')
    end

    let(:ci_yaml) do
      YAML.dump({
        test: {
          stage: 'test',
          script: 'echo',
          only: ['merge_requests']
        }
      })
    end

    before do
      source_project.add_developer(user)
      target_project.add_developer(user)
      source_project.merge_pipelines_enabled = merge_pipelines_enabled
      stub_licensed_features(merge_pipelines: merge_pipelines_license, multiple_approval_rules: true)
      stub_ci_pipeline_yaml_file(ci_yaml)
    end

    shared_examples_for 'detached merge request pipeline' do
      it 'creates a detached merge request pipeline' do
        subject

        expect(merge_request.all_pipelines.count).to eq(1)
        expect(merge_request.all_pipelines.last).not_to be_merged_result_pipeline
        expect(merge_request.all_pipelines.last).to be_detached_merge_request_pipeline
      end

      it 'responds with success', :aggregate_failures do
        expect(subject).to be_success
        expect(subject.payload).to eq(Ci::Pipeline.last)
      end
    end

    shared_examples_for 'merged result pipeline' do
      it 'creates a merge result pipeline' do
        allow(::Ci::CreatePipelineService).to(receive(:new).with(
          anything, anything, a_hash_including(pipeline_creation_request: nil)
        )).and_call_original

        subject

        expect(merge_request.all_pipelines.count).to eq(1)
        expect(merge_request.all_pipelines.last).to be_merged_result_pipeline
        expect(merge_request.all_pipelines.last).not_to be_detached_merge_request_pipeline
      end

      it 'responds with success', :aggregate_failures do
        expect(subject).to be_success
        expect(subject.payload).to eq(Ci::Pipeline.last)
      end
    end

    context 'when push options contain ci.skip' do
      let(:params) { { push_options: { ci: { skip: true } } } }

      it 'creates a skipped pipeline' do
        subject

        expect(merge_request.all_pipelines.count).to eq(1)
        pipeline = merge_request.all_pipelines.last
        expect(pipeline).to be_merged_result_pipeline
        expect(pipeline.builds).to be_empty
        expect(pipeline).to be_skipped
      end
    end

    context 'when merge request is a draft' do
      before do
        merge_request.update!(title: merge_request.draft_title)
      end

      it_behaves_like 'merged result pipeline'
    end

    context 'when merge request requires an approval' do
      before do
        create(:approval_merge_request_rule,
          merge_request: merge_request,
          users: [user],
          name: 'some-custom-rule',
          approvals_required: 1)
      end

      it_behaves_like 'merged result pipeline'
    end

    context 'when project setting for merge request pipelines is disabled' do
      let(:merge_pipelines_enabled) { false }

      it_behaves_like 'detached merge request pipeline'
    end

    context 'when merge request is submitted from fork' do
      let(:source_project) { fork_project(project, nil, repository: true) }

      it_behaves_like 'detached merge request pipeline'
    end

    context 'when the CreateService is retried' do
      it 'does not create a merge request pipeline twice' do
        expect do
          2.times { service.execute(merge_request) }
        end.to change { Ci::Pipeline.count }.by(1)
      end
    end

    context 'when merge request has no commit' do
      let(:source_branch) { 'empty-branch' }

      it_behaves_like 'detached merge request pipeline'
    end

    context 'when merge request has a conflict' do
      let(:source_branch) { 'feature' }
      let(:target_branch) { 'feature_conflict' }

      it_behaves_like 'detached merge request pipeline'
    end

    context 'when workflow:rules are specified' do
      let(:source_branch) { 'feature' }
      let(:target_branch) { 'feature_conflict' }

      context 'when bridge job is used' do
        let(:config) do
          {
            workflow: {
              rules: [
                { if: '$CI_MERGE_REQUEST_ID' }
              ]
            },
            bridge_job: {
              needs: { pipeline: 'some/project' }
            }
          }
        end

        it_behaves_like 'detached merge request pipeline'
      end
    end

    context 'when .gitlab-ci.yml is invalid' do
      let(:ci_yaml) { 'invalid yaml file' }

      it 'persists a pipeline with a config error', :aggregate_failures do
        expect { subject }.to change { Ci::Pipeline.count }.by(1)
        expect(merge_request.all_pipelines.last).to be_failed
        expect(merge_request.all_pipelines.last).to be_config_error
      end

      it 'responds with error', :aggregate_failures do
        expect(subject).to be_error
        expect(subject.message).to eq('Cannot create a pipeline for this merge request.')
      end
    end
  end
end
