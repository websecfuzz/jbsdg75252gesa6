# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::KnowledgeGraph::Task, feature_category: :global_search do
  let_it_be_with_reload(:replica) { create(:knowledge_graph_replica) }

  subject(:task) { create(:knowledge_graph_task, knowledge_graph_replica: replica) }

  describe 'relations' do
    it { is_expected.to belong_to(:node).inverse_of(:knowledge_graph_tasks) }
    it { is_expected.to belong_to(:knowledge_graph_replica).inverse_of(:tasks) }
  end

  describe 'validations' do
    it 'sets namespace_id from associated replica' do
      task.namespace_id = nil

      expect(task).to be_valid
      expect(task.namespace_id).to eq(replica.namespace_id)
    end

    it 'validates if namespace_id equals replica.namespace_id' do
      expect(task).to be_valid

      task.namespace_id = replica.namespace_id.next

      expect(task).not_to be_valid
    end
  end

  describe 'scopes' do
    describe '.with_namespace' do
      let_it_be(:task) { create(:knowledge_graph_task, knowledge_graph_replica: replica) }

      it 'eager loads the namespace and avoids N+1 queries' do
        task = described_class.with_namespace.first
        recorder = ActiveRecord::QueryRecorder
          .new { task.knowledge_graph_replica.knowledge_graph_enabled_namespace.namespace }
        expect(recorder.count).to be_zero
        expect(task.association(:knowledge_graph_replica).loaded?).to be(true)
      end
    end

    describe '.for_namespace' do
      let_it_be(:replica2) do
        create(:knowledge_graph_replica, knowledge_graph_enabled_namespace: replica.knowledge_graph_enabled_namespace)
      end

      let_it_be(:task1) { create(:knowledge_graph_task, knowledge_graph_replica: replica) }
      let_it_be(:task2) { create(:knowledge_graph_task, knowledge_graph_replica: replica2) }
      let_it_be(:task3) { create(:knowledge_graph_task) }

      it 'returns only tasks for replicas of the namespace' do
        expect(described_class.for_namespace(replica.knowledge_graph_enabled_namespace))
          .to match_array([task1, task2])
      end
    end

    describe '.perform_now' do
      let_it_be(:task) { create(:knowledge_graph_task, perform_at: 1.day.ago, knowledge_graph_replica: replica) }
      let_it_be(:task2) { create(:knowledge_graph_task, perform_at: 1.day.from_now, knowledge_graph_replica: replica) }

      it 'returns only tasks whose perform_at is older than the current time' do
        results = described_class.perform_now
        expect(results).to include task
        expect(results).not_to include task2
      end
    end

    describe '.pending_or_processing' do
      let_it_be(:task) { create(:knowledge_graph_task, :done, knowledge_graph_replica: replica) }
      let_it_be(:task2) { create(:knowledge_graph_task, :pending, knowledge_graph_replica: replica) }
      let_it_be(:task3) { create(:knowledge_graph_task, :processing, knowledge_graph_replica: replica) }
      let_it_be(:task4) { create(:knowledge_graph_task, :orphaned, knowledge_graph_replica: replica) }
      let_it_be(:task5) { create(:knowledge_graph_task, :failed, knowledge_graph_replica: replica) }

      it 'returns only tasks whose perform_at is older than the current time' do
        results = described_class.pending_or_processing
        expect(results).to include task2, task3
        expect(results).not_to include task, task4, task5
      end
    end

    describe '.processing_queue' do
      let_it_be(:task) { create(:knowledge_graph_task, perform_at: 1.day.ago, knowledge_graph_replica: replica) }
      let_it_be(:task2) { create(:knowledge_graph_task, perform_at: 1.day.from_now, knowledge_graph_replica: replica) }
      let_it_be(:task3) do
        create(:knowledge_graph_task, :done, perform_at: 1.day.ago, knowledge_graph_replica: replica)
      end

      let_it_be(:task4) do
        create(:knowledge_graph_task, :processing, perform_at: 1.day.ago, knowledge_graph_replica: replica)
      end

      it 'returns only pending or processing tasks where perform_at is older than current time' do
        results = described_class.processing_queue
        expect(results).to include task, task4
        expect(results).not_to include task2, task3
      end
    end
  end

  describe '.each_task_for_processing' do
    it 'returns tasks sorted by performed_at and unique by namespace and moves the task to processing' do
      task_1 = create(:knowledge_graph_task, perform_at: 1.minute.ago)
      task_2 = create(:knowledge_graph_task, perform_at: 3.minutes.ago)
      task_with_same_namespace = create(:knowledge_graph_task,
        knowledge_graph_replica: task_2.knowledge_graph_replica, perform_at: 5.minutes.ago)
      task_in_future = create(:knowledge_graph_task, perform_at: 3.minutes.from_now)

      allow(described_class).to receive(:determine_task_state).and_return(:valid)

      tasks = []
      described_class.each_task_for_processing(limit: 10) { |task| tasks << task }

      expect(tasks.all? { |task| task.reload.processing? }).to be true
      expect(tasks).not_to include(task_2, task_in_future)
      expect(tasks).to contain_exactly(task_with_same_namespace, task_1)
    end

    context 'with orphaned task' do
      let_it_be(:orphaned_indexing_task) { create(:knowledge_graph_task) }
      let_it_be(:orphaned_delete_task) { create(:knowledge_graph_task, task_type: :delete_graph_repo) }

      before do
        orphaned_indexing_task.knowledge_graph_replica.knowledge_graph_enabled_namespace.namespace.destroy!
        orphaned_delete_task.knowledge_graph_replica.knowledge_graph_enabled_namespace.namespace.destroy!
      end

      it 'marks indexing tasks as orphaned' do
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.to change { orphaned_indexing_task.reload.state }.from('pending').to('orphaned')
        expect(orphaned_delete_task.reload.state).to eq('processing')
      end
    end

    context 'with failed repo task' do
      let_it_be(:failed_repo_indexing_task) { create(:knowledge_graph_task) }
      let_it_be(:failed_repo_delete_task) { create(:knowledge_graph_task, task_type: :delete_graph_repo) }

      before do
        failed_repo_indexing_task.knowledge_graph_replica.failed!
        failed_repo_delete_task.knowledge_graph_replica.failed!
      end

      it 'marks indexing tasks as skipped' do
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.to change { failed_repo_indexing_task.reload.state }.from('pending').to('skipped')
        expect(failed_repo_delete_task.reload).to be_processing
      end
    end

    context 'with pending_deletion repo task' do
      let_it_be(:pending_deletion_repo_indexing_task) { create(:knowledge_graph_task) }
      let_it_be(:pending_deletion_repo_delete_task) do
        create(:knowledge_graph_task, task_type: :delete_graph_repo)
      end

      before do
        pending_deletion_repo_indexing_task.knowledge_graph_replica.pending_deletion!
        pending_deletion_repo_delete_task.knowledge_graph_replica.pending_deletion!
      end

      it 'marks indexing tasks as skipped and processes delete tasks' do
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.to change { pending_deletion_repo_indexing_task.reload.state }.from('pending').to('skipped')
        expect(pending_deletion_repo_delete_task.reload).to be_processing
      end

      it 'updates repository states correctly' do
        # Repository state should remain pending_deletion for indexing task since it's skipped
        # Delete task repository state should not be changed here since it's processed normally
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.not_to change { pending_deletion_repo_indexing_task.knowledge_graph_replica.reload.state }

        expect(pending_deletion_repo_indexing_task.knowledge_graph_replica.reload).to be_pending_deletion
      end
    end

    context 'with failed zoekt task' do
      it 'does not mark tasks as processing even with retries left' do
        # Create a failed task that still has retries left
        failed_task = create(:knowledge_graph_task,
          perform_at: 1.minute.ago,
          state: :failed,
          retries_left: 2)

        # Run the task processing
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.not_to change { failed_task.reload.state }.from('failed')
      end

      it 'does not mark tasks as processing with no retries left' do
        # Create a failed task with no retries left
        failed_task = create(:knowledge_graph_task,
          perform_at: 1.minute.ago,
          state: :failed,
          retries_left: 0)

        # Run the task processing
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.not_to change { failed_task.reload.state }.from('failed')
      end
    end
  end

  describe '.update_task_states' do
    let_it_be(:skipped_tasks) { create_list(:knowledge_graph_task, 3, :pending, knowledge_graph_replica: replica) }
    let_it_be(:orphaned_tasks) { create_list(:knowledge_graph_task, 2, :pending, knowledge_graph_replica: replica) }
    let_it_be(:valid_tasks) { create_list(:knowledge_graph_task, 4, :pending, knowledge_graph_replica: replica) }
    let_it_be(:done_tasks) { create_list(:knowledge_graph_task, 2, :pending, knowledge_graph_replica: replica) }

    let(:states) do
      {
        skipped: skipped_tasks.map(&:id),
        orphaned: orphaned_tasks.map(&:id),
        valid: valid_tasks.map(&:id),
        done: done_tasks.map(&:id)
      }
    end

    it 'updates tasks to their appropriate states' do
      freeze_time do
        expect do
          described_class.update_task_states(states: states)
        end.to change { skipped_tasks.map { |t| t.reload.skipped? }.all? }.from(false).to(true)
          .and change { orphaned_tasks.map { |t| t.reload.orphaned? }.all? }.from(false).to(true)
          .and change { valid_tasks.map { |t| t.reload.processing? }.all? }.from(false).to(true)
          .and change { done_tasks.map { |t| t.reload.done? }.all? }.from(false).to(true)

        # Check that updated_at was set for all tasks
        skipped_tasks.each { |t| expect(t.reload.updated_at).to eq(Time.current) }
        orphaned_tasks.each { |t| expect(t.reload.updated_at).to eq(Time.current) }
        valid_tasks.each { |t| expect(t.reload.updated_at).to eq(Time.current) }
        done_tasks.each { |t| expect(t.reload.updated_at).to eq(Time.current) }

        # Only done tasks should cause their repositories to be marked as ready
        done_repo_ids = done_tasks.map { |t| t.knowledge_graph_replica.id }
        expect(Search::Zoekt::Repository.id_in(done_repo_ids).all?(&:ready?)).to be true
      end
    end
  end

  describe '.determine_task_state' do
    let_it_be(:project) { create(:project, :repository) }

    context 'for delete_graph_repo task' do
      let(:task) { create(:knowledge_graph_task, task_type: :delete_graph_repo) }

      it 'returns :valid regardless of repository state' do
        task.knowledge_graph_replica.pending_deletion!
        expect(described_class.determine_task_state(task)).to eq(:valid)
      end
    end

    context 'for index_repo task' do
      let_it_be_with_reload(:enabled_namespace) do
        create(:knowledge_graph_enabled_namespace, namespace: project.project_namespace)
      end

      let_it_be_with_reload(:replica) do
        create(:knowledge_graph_replica, knowledge_graph_enabled_namespace: enabled_namespace)
      end

      let(:task) { create(:knowledge_graph_task, knowledge_graph_replica: replica) }

      context 'when repository is pending_deletion' do
        before do
          task.knowledge_graph_replica.pending_deletion!
        end

        it 'returns :skipped' do
          expect(described_class.determine_task_state(task)).to eq(:skipped)
        end
      end

      context 'when repository is failed' do
        before do
          task.knowledge_graph_replica.failed!
        end

        it 'returns :skipped' do
          expect(described_class.determine_task_state(task)).to eq(:skipped)
        end
      end

      context 'when namespace does not exist' do
        before do
          allow(task.knowledge_graph_replica).to receive(:knowledge_graph_enabled_namespace).and_return(nil)
        end

        it 'returns :orphaned' do
          expect(described_class.determine_task_state(task)).to eq(:orphaned)
        end
      end

      context 'when project repo does not exist' do
        before do
          allow(task.knowledge_graph_replica.knowledge_graph_enabled_namespace.namespace.project)
            .to receive(:repo_exists?).and_return(false)
        end

        it 'returns :done' do
          expect(described_class.determine_task_state(task)).to eq(:done)
        end
      end

      context 'when project repo exists and repository is ready' do
        before do
          task.knowledge_graph_replica.ready!
          allow(project).to receive(:repo_exists?).and_return(true)
        end

        it 'returns :valid' do
          expect(described_class.determine_task_state(task)).to eq(:valid)
        end
      end
    end
  end

  describe 'sliding_list partitioning' do
    let(:partition_manager) { Gitlab::Database::Partitioning::PartitionManager.new(described_class) }

    describe 'next_partition_if callback' do
      let(:active_partition) { described_class.partitioning_strategy.active_partition }

      subject(:value) { described_class.partitioning_strategy.next_partition_if.call(active_partition) }

      context 'when the partition is empty' do
        it { is_expected.to be(false) }
      end

      context 'when the partition has records' do
        before do
          create(:knowledge_graph_task, state: :pending, knowledge_graph_replica: replica)
          create(:knowledge_graph_task, state: :done, knowledge_graph_replica: replica)
          create(:knowledge_graph_task, state: :failed, knowledge_graph_replica: replica)
        end

        it { is_expected.to be(false) }

        context 'when the first record of the partition is older than PARTITION_DURATION' do
          before do
            described_class.first.update!(created_at: (described_class::PARTITION_DURATION + 1.day).ago)
          end

          it { is_expected.to be(true) }
        end
      end
    end

    describe 'detach_partition_if callback' do
      let(:active_partition) { described_class.partitioning_strategy.active_partition }

      subject(:value) { described_class.partitioning_strategy.detach_partition_if.call(active_partition) }

      context 'when the partition contains pending records' do
        let!(:task) { create(:knowledge_graph_task, state: :pending, knowledge_graph_replica: replica) }

        it { is_expected.to be(false) }
      end

      context 'when the partition is empty' do
        it { is_expected.to be(true) }
      end

      context 'when the partition contains processing records' do
        let!(:task) { create(:knowledge_graph_task, state: :processing, knowledge_graph_replica: replica) }

        it { is_expected.to be(false) }
      end

      context 'when the newest record of the partition is older than PARTITION_CLEANUP_THRESHOLD' do
        let_it_be(:created_at) { (described_class::PARTITION_CLEANUP_THRESHOLD + 1.day).ago }

        let_it_be(:task_failed) do
          create(:knowledge_graph_task, state: :failed, created_at: created_at, knowledge_graph_replica: replica)
        end

        let_it_be(:task_done) do
          create(:knowledge_graph_task, state: :done, created_at: created_at, knowledge_graph_replica: replica)
        end

        let_it_be(:task_orphaned) do
          create(:knowledge_graph_task, state: :orphaned, created_at: created_at, knowledge_graph_replica: replica)
        end

        context 'when the partition does not contain pending or processing records' do
          it { is_expected.to be(true) }
        end

        context 'when there are pending or processing records' do
          let_it_be(:task_pending) do
            create(:knowledge_graph_task, state: :pending, created_at: created_at, knowledge_graph_replica: replica)
          end

          it { is_expected.to be(false) }
        end

        context 'when there are pending or processing records for orphaned node' do
          let_it_be(:task_pending) do
            create(:knowledge_graph_task, state: :pending, created_at: created_at,
              zoekt_node_id: non_existing_record_id, knowledge_graph_replica: replica)
          end

          it { is_expected.to be(true) }
        end
      end
    end
  end
end
