# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeTrains::RefreshMergeRequestService, feature_category: :source_code_management do
  let(:project) { create(:project, :repository, merge_pipelines_enabled: true, merge_trains_enabled: true) }
  let_it_be(:maintainer) { create(:user) }

  let(:service) { described_class.new(project, maintainer, require_recreate: require_recreate) }
  let(:require_recreate) { false }
  let(:expected_create_mergeable_ref) { true }

  before do
    project.add_maintainer(maintainer)
    stub_licensed_features(merge_pipelines: true, merge_trains: true)
    project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true) unless project.merge_pipelines_enabled == true && project.merge_trains_enabled == true
  end

  describe '#execute' do
    subject { service.execute(merge_request) }

    let!(:merge_request) do
      create(:merge_request, :on_train,
        train_creator: maintainer,
        source_branch: 'feature', source_project: project,
        target_branch: 'master', target_project: project)
    end

    shared_examples_for 'drops the merge request from the merge train' do
      let(:expected_reason) { 'unknown' }

      specify do
        expect_next_instance_of(AutoMerge::MergeTrainService) do |service|
          expect(service).to receive(:abort).with(merge_request, expected_reason, hash_including(process_next: false))
        end

        subject
      end
    end

    shared_examples_for 'creates a pipeline for merge train' do
      let(:previous_ref) { 'refs/heads/master' }

      specify do
        expect_next_instance_of(MergeTrains::CreatePipelineService, project, maintainer) do |pipeline_service|
          allow(pipeline_service).to receive(:execute) { { status: :success, pipeline: pipeline } }
          expect(pipeline_service).to receive(:execute).with(merge_request, previous_ref, expected_create_mergeable_ref)
        end

        result = subject
        expect(result[:status]).to eq(:success)
        expect(result[:pipeline_created]).to eq(true)
        expect(merge_request.merge_train_car).to be_fresh
      end
    end

    shared_examples_for 'cancels and recreates a pipeline for the merge train' do
      let(:previous_ref) { 'refs/heads/master' }

      it 'cancels and recreates a pipeline for the merge train', :sidekiq_might_not_need_inline do
        expect_next_instance_of(MergeTrains::CreatePipelineService, project, maintainer) do |pipeline_service|
          allow(pipeline_service).to receive(:execute) { { status: :success, pipeline: create(:ci_pipeline) } }
          expect(pipeline_service).to receive(:execute).with(merge_request, previous_ref, expected_create_mergeable_ref)
        end

        result = subject
        new_pipeline = merge_request.merge_train_car.pipeline
        pipeline.reset

        expect(result[:status]).to eq(:success)
        expect(result[:pipeline_created]).to eq(true)
        expect(pipeline.status).to eq('canceled')
        expect(pipeline.auto_canceled_by_id).to eq(new_pipeline.id)
      end
    end

    shared_examples_for 'does not create a pipeline' do
      specify do
        expect(service).not_to receive(:create_pipeline!)

        result = subject
        expect(result[:status]).to eq(:success)
        expect(result[:pipeline_created]).to be_falsy
      end
    end

    shared_examples_for 'merges the merge request' do
      specify do
        expect(merge_request).to receive(:schedule_cleanup_refs).with(only: :train)
        expect(merge_request.merge_train_car).to receive(:start_merge!).and_call_original
        expect(merge_request.merge_train_car).to receive(:finish_merge!).and_call_original
        expect_next_instance_of(MergeRequests::MergeService, project: project, current_user: maintainer, params: instance_of(HashWithIndifferentAccess)) do |service|
          expect(service).to receive(:execute).with(merge_request, skip_discussions_check: true, check_mergeability_retry_lease: true).and_call_original
        end

        expect { subject }.to change { merge_request.merge_train_car.status_name }.from(:fresh).to(:merged)
        expect(merge_request.state).to eq("merged")
      end
    end

    context 'when merge pipelines project configuration is disabled' do
      before do
        project.update!(merge_pipelines_enabled: false)
      end

      it_behaves_like 'drops the merge request from the merge train' do
        let(:expected_reason) { 'project disabled merge trains' }
      end
    end

    context 'when merge trains not enabled' do
      before do
        project.update!(merge_trains_enabled: false)
      end

      it_behaves_like 'drops the merge request from the merge train' do
        let(:expected_reason) { 'project disabled merge trains' }
      end
    end

    context 'when merge request is not in a mergeable state' do
      context 'when merge request is a draft' do
        before do
          merge_request.update!(title: merge_request.draft_title)
        end

        it_behaves_like 'drops the merge request from the merge train' do
          let(:expected_reason) do
            'the merge request is marked as draft. ' \
              '[Learn more](http://localhost/help/ci/pipelines/merge_trains.md#merge-request-dropped-from-the-merge-train).'
          end
        end
      end

      context 'when merge request is not open' do
        before do
          allow(merge_request).to receive(:open?).and_return(false)
        end

        it_behaves_like 'drops the merge request from the merge train' do
          let(:expected_reason) do
            'the merge request is closed. ' \
              '[Learn more](http://localhost/help/ci/pipelines/merge_trains.md#merge-request-dropped-from-the-merge-train).'
          end
        end
      end

      context 'when merge request is broken' do
        before do
          allow(merge_request).to receive(:broken?).and_return(true)
        end

        it_behaves_like 'drops the merge request from the merge train' do
          let(:expected_reason) do
            'the merge request is broken. ' \
              '[Learn more](http://localhost/help/ci/pipelines/merge_trains.md#merge-request-dropped-from-the-merge-train).'
          end
        end
      end

      context 'when auto merge is not set' do
        before do
          # simulate clearing the auto merge parameters with a car present
          merge_request.update!(auto_merge_enabled: false, merge_user_id: nil)
        end

        it_behaves_like 'drops the merge request from the merge train' do
          let(:expected_reason) do
            'the merge request is not set to auto-merge'
          end
        end
      end
    end

    context 'when pipeline for merge train failed' do
      let(:pipeline) { create(:ci_pipeline, :failed) }

      before do
        merge_request.merge_train_car.update!(pipeline: pipeline)
      end

      it_behaves_like 'drops the merge request from the merge train' do
        let(:expected_reason) do
          'the pipeline did not succeed. ' \
            '[Learn more](http://localhost/help/ci/pipelines/merge_trains.md#merge-request-dropped-from-the-merge-train).'
        end
      end
    end

    context 'when merge request is to be squashed' do
      before do
        merge_request.update!(squash: true)
      end

      let(:pipeline) { create(:ci_pipeline) }

      it_behaves_like 'creates a pipeline for merge train'
    end

    context 'when previous ref is not found' do
      let(:previous_ref) { 'refs/tmp/test' }

      before do
        allow(merge_request.merge_train_car).to receive(:previous_ref) { previous_ref }
      end

      it_behaves_like 'drops the merge request from the merge train' do
        let(:expected_reason) do
          'the previous ref does not exist. ' \
            '[Learn more](http://localhost/help/ci/pipelines/merge_trains.md#merge-request-dropped-from-the-merge-train).'
        end
      end
    end

    context 'when pipeline has not been created yet' do
      let(:pipeline) { create(:ci_pipeline) }

      context 'when the merge request is the first queue' do
        it_behaves_like 'creates a pipeline for merge train'

        context 'when it failed to create a pipeline' do
          before do
            allow_next_instance_of(MergeTrains::CreatePipelineService) do |instance|
              allow(instance).to receive(:execute) { { result: :error, message: 'failed to create pipeline' } }
            end
          end

          it_behaves_like 'drops the merge request from the merge train' do
            let(:expected_reason) { 'failed to create pipeline' }
          end
        end
      end
    end

    context 'when pipeline for merge train is running' do
      let(:pipeline) { create(:ci_pipeline, :running, :with_job, project: project, target_sha: previous_ref_sha, source_sha: merge_request.diff_head_sha) }
      let(:previous_ref_sha) { project.repository.commit('refs/heads/master').sha }

      before do
        merge_request.merge_train_car.refresh_pipeline!(pipeline.id)
      end

      context 'when the pipeline is not stale' do
        it_behaves_like 'does not create a pipeline'
      end

      context 'when the pipeline is stale' do
        before do
          merge_request.merge_train_car.update_column(:status, MergeTrains::Car.state_machines[:status].states[:stale].value)
        end

        it_behaves_like 'cancels and recreates a pipeline for the merge train'
      end

      context 'when the pipeline is required to be recreated' do
        let(:require_recreate) { true }

        it_behaves_like 'cancels and recreates a pipeline for the merge train'
      end

      context 'when discussion is added and project is set to only merge if all discussions resolved' do
        before do
          project.update!(only_allow_merge_if_all_discussions_are_resolved: true)
        end

        it 'continues with the current pipeline' do
          create(:discussion_note_on_merge_request, noteable: merge_request, project: project)

          result = subject

          expect(result[:pipeline_created]).to eq(false)
          expect(result[:status]).to eq(:success)
          expect(merge_request.merge_status).to eq("can_be_merged")
          expect(merge_request.merge_params).to eq({ "auto_merge_strategy" => "merge_train" })
        end
      end
    end

    context 'when pipeline for merge train succeeded' do
      let(:previous_ref_sha) { project.repository.commit('refs/heads/master').sha }
      let(:pipeline) { create(:ci_pipeline, :success, target_sha: previous_ref_sha, source_sha: merge_request.diff_head_sha) }

      before do
        merge_request.merge_train_car.refresh_pipeline!(pipeline.id)
        merge_request.merge_params['sha'] = merge_request.diff_head_sha
        merge_request.save!
      end

      context 'when a new discussion is added and project only allow merges when all discussions are resolved' do
        before do
          project.update!(only_allow_merge_if_all_discussions_are_resolved: true)
          create(:discussion_note_on_merge_request, noteable: merge_request, project: project)
        end

        it_behaves_like 'merges the merge request'
      end

      context 'when the merge request is the first queue' do
        let(:policy) { create(:scan_result_policy_read, project: project) }

        it_behaves_like 'merges the merge request'

        context 'when a security scan is running' do
          before do
            create(:scan_result_policy_violation, :running, project: project, merge_request: merge_request,
              scan_result_policy_read: policy, violation_data: nil)
          end

          it 'logs that the scan is running' do
            project.update!(merge_method: :ff)
            project.repository.raw_repository.write_ref(merge_request.train_ref_path, pipeline.sha)
            expect(Gitlab::AppLogger).to receive(:warn).with("Security scans running")

            subject
          end
        end

        context 'when no scan is running' do
          before do
            create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
              scan_result_policy_read: policy, violation_data: nil)
          end

          it 'does not log' do
            project.update!(merge_method: :ff)
            project.repository.raw_repository.write_ref(merge_request.train_ref_path, pipeline.sha)
            expect(Gitlab::AppLogger).not_to receive(:warn)

            subject
          end
        end

        using RSpec::Parameterized::TableSyntax

        where(:merge_method) do
          [:ff, :rebase_merge]
        end

        with_them do
          before do
            project.update!(merge_method: merge_method)
            project.repository.raw_repository.write_ref(merge_request.train_ref_path, pipeline.sha)
          end

          context 'when it is not safe to merge directly from ref' do
            it 'uses the default merge strategy' do
              expect_next_instance_of(MergeRequests::MergeService, project: project, current_user: maintainer, params: instance_of(HashWithIndifferentAccess)) do |service|
                expect(service).to receive(:execute).with(merge_request, skip_discussions_check: true, check_mergeability_retry_lease: true)
              end

              subject
            end
          end

          context 'when it is safe to merge directly from ref' do
            before do
              merge_request.update!(
                merge_params: merge_request.merge_params.merge(
                  'train_ref' => {
                    'commit_sha' => pipeline.sha
                  }
                )
              )
            end

            it 'uses the FromTrainRef merge strategy', :aggregate_failures do
              expect(merge_request).to receive(:schedule_cleanup_refs).with(only: :train)
              expect(merge_request.merge_train_car).to receive(:start_merge!).and_call_original
              expect(merge_request.merge_train_car).to receive(:finish_merge!).and_call_original
              expect_next_instance_of(MergeRequests::MergeService, project: project, current_user: maintainer, params: instance_of(HashWithIndifferentAccess)) do |service|
                expect(service).to(
                  receive(:execute).with(
                    merge_request,
                    skip_discussions_check: true,
                    check_mergeability_retry_lease: true,
                    merge_strategy: MergeRequests::MergeStrategies::FromTrainRef
                  ).and_call_original
                )
              end

              expect { subject }.to change { merge_request.merge_train_car.status_name }.from(:fresh).to(:merged)
              expect(subject[:status]).to eq(:success)
              expect(subject[:message]).to eq(nil)
              expect(merge_request.state).to eq("merged")
            end
          end
        end

        context 'when it failed to merge the merge request' do
          before do
            allow(merge_request).to receive(:broken?) { false }
            merge_request.update!(merge_error: 'Branch has been updated since the merge was requested.')
            allow_next_instance_of(MergeRequests::MergeService) do |instance|
              allow(instance).to receive(:execute) { { result: :error } }
            end
          end

          it 'does not finish merge and drops the merge request from train' do
            expect(merge_request).to be_on_train
            expect(merge_request.merge_train_car).to receive(:start_merge!).and_call_original
            expect(merge_request.merge_train_car).not_to receive(:finish_merge!)

            subject

            expect(merge_request).not_to be_on_train
          end

          it_behaves_like 'drops the merge request from the merge train' do
            let(:expected_reason) { 'failed to merge. Branch has been updated since the merge was requested.' }
          end
        end
      end

      context 'when the merge request is not the first queue' do
        before do
          allow(merge_request.merge_train_car).to receive(:first_car?).and_return(false)
        end

        it 'does not merge the merge request' do
          expect(MergeRequests::MergeService).not_to receive(:new)

          subject
        end
      end
    end
  end
end
