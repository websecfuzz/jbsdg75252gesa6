# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Repository, feature_category: :global_search do
  subject { create(:zoekt_repository) }

  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_index).inverse_of(:zoekt_repositories) }
    it { is_expected.to belong_to(:project).inverse_of(:zoekt_repositories) }
  end

  describe 'before_validation' do
    let_it_be(:zoekt_repo) { create(:zoekt_repository) }

    it 'sets project_identifier equal to project_id' do
      zoekt_repo.project_identifier = nil
      expect { zoekt_repo.valid? }.to change { zoekt_repo.project_identifier }.from(nil).to(zoekt_repo.project_id)
    end
  end

  describe 'attribute :retries_left' do
    subject(:repository) { build(:zoekt_repository) }

    it 'has a default value of 3' do
      expect(repository.retries_left).to eq(3)
    end
  end

  describe 'validation' do
    let_it_be_with_reload(:zoekt_repo) { create(:zoekt_repository) }
    let(:zoekt_index) { zoekt_repo.zoekt_index }
    let(:project) { zoekt_repo.project }

    it 'validates project_id and project_identifier' do
      expect { zoekt_repo.project_id = nil }.not_to change { zoekt_repo.valid? }
      expect { zoekt_repo.project_id = zoekt_repo.project_identifier.next }.to change { zoekt_repo.valid? }.to false
    end

    it 'validated uniqueness on zoekt_index_id and project_identifier' do
      expect(zoekt_repo).to be_valid
      zoekt_repo2 = build(:zoekt_repository, project: nil, project_identifier: project.id, zoekt_index: zoekt_index)
      expect(zoekt_repo2).to be_invalid
    end

    it { is_expected.to validate_presence_of(:zoekt_index_id) }
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:schema_version) }
  end

  describe 'scope' do
    describe '.uncompleted' do
      let_it_be(:zoekt_repository) { create(:zoekt_repository, state: :pending) }

      it 'returns non ready records' do
        create(:zoekt_repository, state: :ready)
        create(:zoekt_repository, state: :failed)
        expect(described_class.uncompleted).to contain_exactly zoekt_repository
      end
    end

    describe '.for_zoekt_indices' do
      let_it_be(:zoekt_index) { create(:zoekt_index) }
      let_it_be(:zoekt_index2) { create(:zoekt_index) }
      let_it_be(:zoekt_index3) { create(:zoekt_index) }
      let_it_be(:zoekt_repository) { create(:zoekt_repository, zoekt_index: zoekt_index) }
      let_it_be(:zoekt_repository2) { create(:zoekt_repository, zoekt_index: zoekt_index) }
      let_it_be(:zoekt_repository3) { create(:zoekt_repository, zoekt_index: zoekt_index2) }

      it 'returns records for matching zoekt indices' do
        create(:zoekt_repository, zoekt_index: zoekt_index3)
        expect(described_class.for_zoekt_indices([zoekt_index, zoekt_index2])).to contain_exactly zoekt_repository,
          zoekt_repository2, zoekt_repository3
      end
    end

    describe '.indexable' do
      let_it_be(:ready) { create(:zoekt_repository, state: :ready) }
      let_it_be(:pending) { create(:zoekt_repository, state: :pending) }
      let_it_be(:initializing) { create(:zoekt_repository, state: :initializing) }
      let_it_be(:orphaned) { create(:zoekt_repository, state: :orphaned) }
      let_it_be(:pending_deletion) { create(:zoekt_repository, state: :pending_deletion) }
      let_it_be(:failed) { create(:zoekt_repository, state: :failed) }

      subject(:records) { described_class.indexable }

      it 'returns all repositories with state includes in INDEXABLE_STATES' do
        expect(records).to include pending, initializing, ready
        expect(records).not_to include orphaned, pending_deletion, failed
      end
    end

    describe '.searchable' do
      let_it_be(:ready) { create(:zoekt_repository, state: :ready) }
      let_it_be(:pending) { create(:zoekt_repository, state: :pending) }
      let_it_be(:initializing) { create(:zoekt_repository, state: :initializing) }
      let_it_be(:orphaned) { create(:zoekt_repository, state: :orphaned) }
      let_it_be(:pending_deletion) { create(:zoekt_repository, state: :pending_deletion) }
      let_it_be(:failed) { create(:zoekt_repository, state: :failed) }

      subject(:records) { described_class.searchable }

      it 'returns all repositories with state includes in SEARCHABLE_STATES' do
        expect(records).to include ready
        expect(records).not_to include pending, initializing, orphaned, pending_deletion, failed
      end
    end

    describe '.should_be_indexed' do
      let_it_be(:ready) { create(:zoekt_repository, state: :ready) }
      let_it_be(:ready_mismatch_schema_version) { create(:zoekt_repository, state: :ready, schema_version: 2510) }
      let_it_be(:pending) { create(:zoekt_repository, state: :pending) }
      let_it_be(:orphaned) { create(:zoekt_repository, state: :orphaned) }
      let_it_be(:pending_deletion) { create(:zoekt_repository, state: :pending_deletion) }
      let_it_be(:failed) { create(:zoekt_repository, state: :failed) }
      let_it_be(:initializing) { create(:zoekt_repository, state: :initializing) }
      let_it_be(:initializing_mismatch_schema_version) do
        create(:zoekt_repository, state: :initializing, schema_version: 2510)
      end

      subject(:records) { described_class.should_be_indexed }

      it 'returns all repositories with pending states and indexable states with mismatched schema_version' do
        expect(records).to include ready_mismatch_schema_version, pending, initializing_mismatch_schema_version
        expect(records).not_to include ready, initializing, orphaned, pending_deletion, failed
      end
    end
  end

  describe '.create_bulk_tasks', :freeze_time do
    let_it_be(:zoekt_repo_with_pending_tasks) { create(:zoekt_repository) }
    let_it_be(:zoekt_repo_with_processing_tasks) { create(:zoekt_repository) }
    let_it_be(:zoekt_repo_without_tasks) { create(:zoekt_repository) }
    let_it_be(:failed_zoekt_repo_without_tasks) { create(:zoekt_repository, :failed) }

    before do
      create(:zoekt_task, :pending, zoekt_repository: zoekt_repo_with_pending_tasks)
      create(:zoekt_task, :pending, task_type: :delete_repo, zoekt_repository: zoekt_repo_with_pending_tasks)
      create(:zoekt_task, :processing, zoekt_repository: zoekt_repo_with_processing_tasks)
      create(:zoekt_task, :processing, task_type: :delete_repo, zoekt_repository: zoekt_repo_with_processing_tasks)
    end

    context 'when task_type is delete_repo' do
      it 'creates zoekt_tasks for failed repos and repos which do not have pending tasks' do
        pending_tasks_count = zoekt_repo_with_pending_tasks.reload.tasks.count
        processing_tasks_count = zoekt_repo_with_processing_tasks.reload.tasks.count
        described_class.create_bulk_tasks(task_type: :delete_repo)
        expect(zoekt_repo_with_pending_tasks.reload.tasks.count).to eq pending_tasks_count
        expect(zoekt_repo_with_processing_tasks.reload.tasks.count).to eq processing_tasks_count + 1
        expect(zoekt_repo_without_tasks.reload.tasks.count).to eq 1
        expect(failed_zoekt_repo_without_tasks.reload.tasks.count).to eq 1
        expect(zoekt_repo_without_tasks).to be_deleted
        expect(zoekt_repo_without_tasks.retries_left).to eq 3
        expect(zoekt_repo_with_processing_tasks).to be_deleted
        expect(zoekt_repo_with_pending_tasks).to be_pending
      end
    end

    context 'when task_type is index_repo' do
      it 'does not creates tasks for failed repos and creates tasks for repos which do not have pending tasks' do
        pending_tasks_count = zoekt_repo_with_pending_tasks.reload.tasks.count
        processing_tasks_count = zoekt_repo_with_processing_tasks.reload.tasks.count
        described_class.create_bulk_tasks
        expect(zoekt_repo_with_pending_tasks.reload.tasks.count).to eq pending_tasks_count
        expect(zoekt_repo_with_processing_tasks.reload.tasks.count).to eq processing_tasks_count + 1
        expect(zoekt_repo_without_tasks.reload.tasks.count).to eq 1
        expect(failed_zoekt_repo_without_tasks.reload.tasks.count).to eq 0
        expect(zoekt_repo_without_tasks).to be_initializing
        expect(zoekt_repo_without_tasks.retries_left).to eq 3
        expect(zoekt_repo_with_processing_tasks).to be_initializing
        expect(zoekt_repo_with_pending_tasks).to be_pending
      end
    end

    context 'when bulk_insert! raises an exception' do
      before do
        allow(Search::Zoekt::Task).to receive(:bulk_insert!).and_raise(ActiveRecord::StatementInvalid)
      end

      it 'raises the exception' do
        initial_zoekt_repo_states = described_class.all.pluck(:state, :id)
        expect { described_class.create_bulk_tasks }.to raise_error(ActiveRecord::StatementInvalid)
                                                          .and not_change { Search::Zoekt::Task.count }
        expect(described_class.all.pluck(:state, :id)).to match_array(initial_zoekt_repo_states)
      end
    end
  end
end
