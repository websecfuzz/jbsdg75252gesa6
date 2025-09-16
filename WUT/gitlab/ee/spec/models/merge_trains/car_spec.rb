# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeTrains::Car, feature_category: :merge_trains do
  include ProjectForksHelper

  let_it_be(:project) { create(:project, :repository) }

  before do
    allow(AutoMergeProcessWorker).to receive(:perform_async)
  end

  it { is_expected.to belong_to(:merge_request) }
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:pipeline) }

  shared_context 'with train cars in many states' do
    let_it_be(:idle_car) { create(:merge_train_car, :idle) }
    let_it_be(:stale_car) { create(:merge_train_car, :stale) }
    let_it_be(:fresh_car) { create(:merge_train_car, :fresh) }
    let_it_be(:merged_car) { create(:merge_train_car, :merged) }
    let_it_be(:merging_car) { create(:merge_train_car, :merging) }
  end

  describe '.create' do
    let(:merge_request) { create(:merge_request, :merged) }

    let(:base_attributes) do
      {
        user: merge_request.author,
        merge_request: merge_request,
        target_project: merge_request.target_project,
        target_branch: merge_request.target_branch
      }
    end

    subject { described_class.create!(attributes) }

    context 'with merged_at and a skip_merged status' do
      let(:attributes) do
        base_attributes.merge(
          merged_at: Time.current,
          status: described_class.state_machine.states[:skip_merged].value
        )
      end

      it 'creates a completed car with no pipeline', :aggregate_failures do
        expect(subject).to be_persisted
        expect(subject).to be_skip_merged
        expect(subject.pipeline).to be_nil
        expect(subject.merged_at).to be_present
      end
    end
  end

  describe '.active' do
    subject { described_class.active }

    include_context 'with train cars in many states'

    it 'returns only active merge trains' do
      is_expected.to contain_exactly(idle_car, stale_car, fresh_car)
    end
  end

  describe '.complete' do
    subject { described_class.complete }

    include_context 'with train cars in many states'

    it 'returns only merged merge trains' do
      is_expected.to contain_exactly(merged_car, merging_car)
    end
  end

  describe '.for_target' do
    subject { described_class.for_target(project_id, branch) }

    let!(:train_car_1) { create(:merge_train_car) }
    let!(:train_car_2) { create(:merge_train_car) }

    context "when target merge train 1's project" do
      let(:project_id) { train_car_1.target_project_id }
      let(:branch) { train_car_1.target_branch }

      it 'returns merge train 1 only' do
        is_expected.to eq([train_car_1])
      end
    end

    context "when target merge train 2's project" do
      let(:project_id) { train_car_2.target_project_id }
      let(:branch) { train_car_2.target_branch }

      it 'returns merge train 2 only' do
        is_expected.to eq([train_car_2])
      end
    end
  end

  describe '.by_id' do
    subject { described_class.by_id }

    let!(:train_car_1) { create(:merge_train_car, target_project: project, target_branch: 'master') }
    let!(:train_car_2) { create(:merge_train_car, target_project: project, target_branch: 'master') }

    it 'returns merge trains by id ASC' do
      is_expected.to eq([train_car_1, train_car_2])
    end
  end

  describe '.indexed' do
    let(:indexed_cars) { described_class.indexed }

    let(:cars) { described_class.all }

    let_it_be(:train_car_1) { create(:merge_train_car, target_project: project, target_branch: 'master') }
    let_it_be(:train_car_2) { create(:merge_train_car, target_project: project, target_branch: 'master') }

    it 'returns merge trains with preloaded indexes' do
      expect { indexed_cars.each(&:index) }.to match_query_count(1)
    end

    it 'indexes the cars correctly' do
      indexed_cars.each do |car|
        non_indexed_car = described_class.find(car.id)
        expect(car.index).to eq(non_indexed_car.index)
      end
    end

    context 'when only one car is loaded from the train' do
      let(:indexed_car) { described_class.indexed.find(train_car_2.id) }

      it 'indexes the cars correctly' do
        non_indexed_car = described_class.find(indexed_car.id)
        expect(indexed_car.index).to eq(non_indexed_car.index)
      end
    end

    context 'when the index is not preloaded' do
      it 'returns merge trains with preloaded indexes' do
        expect { cars.each(&:index) }.to match_query_count(3)
      end
    end
  end

  describe '.insert_skip_merged_car_for', :aggregate_failures do
    let(:maintainer)    { create(:user, maintainer_of: merge_request.project) }
    let(:merge_train)   { MergeTrains::Train.new(merge_request.project_id, merge_request.target_branch) }
    let(:merge_request) { create(:merge_request, :locked) }

    subject { described_class.insert_skip_merged_car_for(merge_request, maintainer) }

    it 'creates and returns a new completed MergeTrain Car record' do
      expect { subject }.to change { MergeTrains::Car.count }.by(1)
      expect(subject).to be_persisted
      expect(subject).to be_skip_merged
      expect(subject.merge_request).to eq(merge_request)
    end
  end

  describe '#all_next' do
    subject { car.all_next }

    let(:car) { merge_request.merge_train_car }
    let!(:merge_request) { create_merge_request_on_train }

    it 'returns nil' do
      is_expected.to be_empty
    end

    context 'when the other merge request is on the merge train' do
      let!(:merge_request_2) { create_merge_request_on_train(source_branch: 'improve/awesome') }

      it 'returns the next merge requests' do
        is_expected.to eq([merge_request_2.merge_train_car])
      end
    end
  end

  describe '#all_prev' do
    subject { train_car.all_prev }

    let(:train_car) { merge_request.merge_train_car }
    let!(:merge_request) { create_merge_request_on_train }

    context 'when the merge request is at first on the train' do
      it 'returns an empty relation' do
        is_expected.to be_empty
      end
    end

    context 'when the merge request is at last on the train' do
      let(:train_car) { merge_request_2.merge_train_car }
      let!(:merge_request_2) { create_merge_request_on_train(source_branch: 'improve/awesome') }

      it 'returns the previous merge requests' do
        is_expected.to eq([merge_request.merge_train_car])
      end

      context 'when the previous merge request has already been merged' do
        let!(:merge_request) { create_merge_request_on_train(status: :merged) }

        it 'returns empty array' do
          is_expected.to be_empty
        end
      end
    end
  end

  describe '#next' do
    subject { train_car.next }

    let(:train_car) { merge_request.merge_train_car }
    let!(:merge_request) { create_merge_request_on_train }

    context 'when the merge request is at last on the train' do
      it 'returns nil' do
        is_expected.to be_nil
      end
    end

    context 'when the other merge request is on the merge train' do
      let!(:merge_request_2) { create_merge_request_on_train(source_branch: 'improve/awesome') }

      it 'returns the next merge request' do
        is_expected.to eq(merge_request_2.merge_train_car)
      end
    end
  end

  describe '#prev' do
    subject { train_car.prev }

    let(:train_car) { merge_request.merge_train_car }
    let!(:merge_request) { create_merge_request_on_train }

    context 'when the merge request is at first on the train' do
      it 'returns nil' do
        is_expected.to be_nil
      end
    end

    context 'when the merge request is at last on the train' do
      let(:train_car) { merge_request_2.merge_train_car }
      let!(:merge_request_2) { create_merge_request_on_train(source_branch: 'improve/awesome') }

      it 'returns the next merge request' do
        is_expected.to eq(merge_request.merge_train_car)
      end
    end
  end

  describe '#previous_ref' do
    subject { train_car.previous_ref }

    let(:train_car) { merge_request.merge_train_car }
    let!(:merge_request) { create_merge_request_on_train }

    context 'when merge request is first on train' do
      it 'returns the target branch' do
        is_expected.to eq(merge_request.target_branch_ref)
      end
    end

    context 'when merge request is not first on train' do
      let(:train_car) { merge_request_2.merge_train_car }
      let!(:merge_request_2) { create_merge_request_on_train(source_branch: 'feature-2') }

      it 'returns the ref of the previous merge request' do
        is_expected.to eq(merge_request.train_ref_path)
      end
    end
  end

  describe '#requires_new_pipeline?' do
    subject { train_car.requires_new_pipeline? }

    let(:train_car) { merge_request.merge_train_car }
    let!(:merge_request) { create_merge_request_on_train }

    context 'when merge train has a pipeline associated' do
      before do
        train_car.update!(pipeline: create(:ci_pipeline, project: train_car.project))
      end

      it { is_expected.to be_falsey }

      context 'when merge train is stale' do
        before do
          train_car.update!(status: described_class.state_machines[:status].states[:stale].value)
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when merge train does not have a pipeline' do
      before do
        train_car.update!(pipeline: nil)
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#pipeline_not_succeeded?' do
    subject { train_car.pipeline_not_succeeded? }

    let(:train_car) { merge_request.merge_train_car }
    let!(:merge_request) { create_merge_request_on_train }

    context 'when merge train does not have a pipeline' do
      it { is_expected.to be_falsey }
    end

    context 'when merge train has a pipeline' do
      let(:pipeline) { create(:ci_pipeline, project: train_car.project, status: status) }

      before do
        train_car.update!(pipeline: pipeline)
      end

      context 'when pipeline failed' do
        let(:status) { :failed }

        it { is_expected.to be_truthy }
      end

      context 'when pipeline succeeded' do
        let(:status) { :success }

        it { is_expected.to be_falsey }
      end

      context 'when pipeline is running' do
        let(:status) { :running }

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#mergeable?' do
    subject { train_car.mergeable? }

    let(:train_car) { merge_request.merge_train_car }
    let!(:merge_request) { create_merge_request_on_train }

    context 'when merge train has successful pipeline' do
      before do
        train_car.update!(pipeline: create(:ci_pipeline, :success, project: merge_request.project))
      end

      context 'when merge request is first on train' do
        it { is_expected.to be_truthy }
      end

      context 'when the other merge request is on the merge train' do
        let(:train_car) { merge_request_2.merge_train_car }
        let!(:merge_request_2) { create_merge_request_on_train(source_branch: 'improve/awesome') }

        it { is_expected.to be_falsy }
      end
    end

    context 'when merge train has non successful pipeline' do
      before do
        train_car.update!(pipeline: create(:ci_pipeline, :failed, project: merge_request.project))
      end

      context 'when merge request is first on train' do
        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#index' do
    subject { train_car.index }

    let!(:merge_request) { create_merge_request_on_train(status: :fresh) }
    let(:train_car) { merge_request.merge_train_car }

    it { is_expected.to eq(0) }

    context 'when the merge train is at the second queue' do
      let!(:merge_request_2) { create_merge_request_on_train(status: :fresh, source_branch: 'improve/awesome') }
      let(:train_car) { merge_request_2.merge_train_car }

      it { is_expected.to eq(1) }

      context 'and the first car is successfully merged', :aggregate_failures do
        let(:refresh_service_execution) do
          merge_request.merge_train_car.start_merge!
          merge_request.merge_train_car.finish_merge!
        end

        it 'removes index from the merged car and reduces the index of Train cars by 1' do
          expect { refresh_service_execution }
            .to change { merge_request.reload.merge_train_car.status_name }.from(:fresh).to(:merged)
            .and change { merge_request.reload.merge_train_car.index }.from(0).to(nil)
            .and change { merge_request_2.reload.merge_train_car.index }.from(1).to(0)
        end
      end
    end
  end

  describe 'status transition' do
    context 'when status is idle' do
      let(:train_car) { create(:merge_train_car) }

      context 'and transits to fresh' do
        let!(:pipeline) { create(:ci_pipeline) }

        it 'refreshes the state and set a pipeline' do
          train_car.refresh_pipeline!(pipeline.id)

          expect(train_car).to be_fresh
          expect(train_car.pipeline).to eq(pipeline)
        end
      end

      context 'and transits to merged' do
        it 'does not allow the transition' do
          expect { train_car.finish_merge! }
            .to raise_error(StateMachines::InvalidTransition)
        end
      end

      context 'and transits to stale' do
        it 'does not allow the transition' do
          expect { train_car.outdate_pipeline! }
            .to raise_error(StateMachines::InvalidTransition)
        end
      end
    end

    context 'when status is fresh' do
      let(:train_car) { create(:merge_train_car, :fresh) }

      context 'and transits to merged' do
        it 'does not allow the transition' do
          expect { train_car.finish_merge! }
            .to raise_error(StateMachines::InvalidTransition)
        end
      end

      context 'and transits to stale' do
        it 'refreshes asynchronously' do
          expect(MergeTrains::RefreshWorker)
            .to receive(:perform_async).with(train_car.target_project_id, train_car.target_branch).once

          train_car.outdate_pipeline!
        end
      end
    end

    context 'when status is merging' do
      let!(:train_car) { create(:merge_train_car, :merging) }

      context 'and transits to merged' do
        it 'persists duration and merged_at' do
          expect(train_car.duration).to be_nil
          expect(train_car.merged_at).to be_nil

          travel_to(1.hour.from_now) do
            train_car.finish_merge!

            train_car.reload
            expect(train_car.merged_at.to_i).to eq(Time.current.to_i)
            expect(train_car.duration).to be_within(1.hour.to_i).of(1.hour.to_i + 1)
          end
        end

        it 'cleans up train car ref' do
          expect(train_car).to receive(:try_cleanup_ref)

          train_car.finish_merge!
        end
      end
    end

    context 'when status is merged' do
      let(:train_car) { create(:merge_train_car, :merged) }

      context 'and transits to merged' do
        it 'does not allow the transition' do
          expect { train_car.finish_merge! }
            .to raise_error(StateMachines::InvalidTransition)
        end
      end
    end
  end

  describe '#destroy' do
    subject { train_car.destroy! }

    context 'when merge train has a pipeline' do
      let(:train_car) { create(:merge_train_car, pipeline: pipeline) }
      let(:pipeline) { create(:ci_pipeline, :running) }
      let(:job) { create(:ci_build, :running, pipeline: pipeline) }

      context 'when canceling is not supported' do
        it 'cancels the jobs in the pipeline' do
          expect { subject }.to change { job.reload.status }.from('running').to('canceled')
        end
      end

      context 'when canceling is supported' do
        include_context 'when canceling support'

        it 'cancels the jobs in the pipeline' do
          expect { subject }.to change { job.reload.status }.from('running').to('canceling')
        end
      end
    end
  end

  describe '#try_cleanup_ref' do
    let(:train_car) { create(:merge_train_car) }

    context 'when running async' do
      subject { train_car.try_cleanup_ref }

      it 'schedules cleanup_refs for merge request' do
        expect(train_car.merge_request).to receive(:schedule_cleanup_refs).with(only: :train)

        subject
      end
    end

    context 'when running immediately' do
      subject { train_car.try_cleanup_ref(async: false) }

      it 'executes cleanup_refs for merge request' do
        expect(train_car.merge_request).to receive(:cleanup_refs).with(only: :train)

        subject
      end
    end

    context 'when the ref deletion fails' do
      before do
        allow(train_car).to receive(:cleanup_ref).and_raise(Gitlab::Git::CommandError, "some message")
      end

      it 'captures the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(an_instance_of(Gitlab::Git::CommandError))
        expect { train_car.try_cleanup_ref }.not_to raise_error
      end
    end
  end

  describe '#active?' do
    subject { train_car.active? }

    context 'when status is idle' do
      let(:train_car) { create(:merge_train_car, :idle) }

      it { is_expected.to eq(true) }
    end

    context 'when status is merged' do
      let(:train_car) { create(:merge_train_car, :merged) }

      it { is_expected.to eq(false) }
    end
  end

  describe '#on_ff_train?' do
    subject { train_car.on_ff_train? }

    let_it_be_with_reload(:fresh_car) { create(:merge_train_car, :fresh) }
    let_it_be(:merged_car) { create(:merge_train_car, :merged) }

    context 'when car is active' do
      let(:train_car) { fresh_car }

      context 'when pipeline is nil' do
        before do
          train_car.update!(pipeline_id: nil)
        end

        it { is_expected.to eq(false) }

        context 'when commit sha is nil' do
          before do
            train_car.merge_request.update!(merge_params: { 'train_ref' => { 'commit_sha' => nil } })
          end

          it { is_expected.to eq(false) }
        end
      end

      context 'when the pipeline sha is the same as the merge request sha' do
        before do
          train_car.merge_request.update!(merge_params: { 'train_ref' => { 'commit_sha' => train_car.pipeline.sha } })
        end

        it { is_expected.to eq(true) }
      end
    end

    context 'when train car is inactive' do
      let(:train_car) { merged_car }

      it { is_expected.to eq(false) }
    end
  end

  describe '#train' do
    include_context 'with train cars in many states'

    it 'returns a MergeTrains::Train regardless of state' do
      [idle_car, stale_car, fresh_car, merging_car, merged_car].each do |car|
        expect(car.train).to be_a(MergeTrains::Train)
      end
    end
  end

  def create_merge_request_on_train(
    target_project: project, target_branch: 'master', source_project: project,
    source_branch: 'feature', status: :idle)
    create(:merge_request,
      :on_train,
      target_branch: target_branch,
      target_project: target_project,
      source_branch: source_branch,
      source_project: source_project,
      status: MergeTrains::Car.state_machines[:status].states[status].value)
  end

  context 'with loose foreign key on merge_trains.pipeline_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:ci_pipeline) }
      let_it_be(:model) { create(:merge_train_car, pipeline: parent) }
    end
  end
end
