# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::Repository, feature_category: :code_suggestions do
  include LooseForeignKeysHelper

  let_it_be(:project) { create(:project) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:enabled_namespace) do
    create(:ai_active_context_code_enabled_namespace, namespace: namespace)
  end

  let(:connection) { enabled_namespace.active_context_connection }
  let(:enabled_namespace_id) { enabled_namespace.id }

  subject(:repository) do
    create(:ai_active_context_code_repository,
      project: project,
      enabled_namespace: enabled_namespace
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:enabled_namespace).class_name('Ai::ActiveContext::Code::EnabledNamespace').optional }
    it { is_expected.to belong_to(:active_context_connection).class_name('Ai::ActiveContext::Connection') }
  end

  describe 'validations' do
    describe 'metadata' do
      it 'is valid for empty hash' do
        repository.metadata = {}
        expect(repository).to be_valid
      end

      it 'is invalid for a random hash' do
        repository.metadata = { key: 'value' }
        expect(repository).not_to be_valid
      end

      it 'is valid with initial_indexing_last_queued_item' do
        repository.metadata = { initial_indexing_last_queued_item: 'item_ref_123' }
        expect(repository).to be_valid
      end

      it 'is valid with null initial_indexing_last_queued_item' do
        repository.metadata = { initial_indexing_last_queued_item: nil }
        expect(repository).to be_valid
      end

      it 'is valid with last_error' do
        repository.metadata = { last_error: 'Something went wrong' }
        expect(repository).to be_valid
      end

      it 'is valid with null last_error' do
        repository.metadata = { last_error: nil }
        expect(repository).to be_valid
      end

      it 'is invalid with wrong type for initial_indexing_last_queued_item' do
        repository.metadata = { initial_indexing_last_queued_item: 123 }
        expect(repository).not_to be_valid
      end

      it 'is invalid with wrong type for last_error' do
        repository.metadata = { last_error: 123 }
        expect(repository).not_to be_valid
      end
    end

    describe 'connection_id uniqueness' do
      it 'validates uniqueness of connection_id scoped to project_id' do
        create(:ai_active_context_code_repository,
          project: project,
          enabled_namespace: enabled_namespace,
          connection_id: connection.id
        )

        repository2 = build(:ai_active_context_code_repository,
          project: project,
          enabled_namespace: enabled_namespace,
          connection_id: connection.id
        )

        expect(repository2).not_to be_valid
        expect(repository2.errors[:connection_id]).to include('has already been taken')
      end

      it 'allows same connection_id for different project_ids' do
        create(:ai_active_context_code_repository,
          project: project,
          enabled_namespace: enabled_namespace,
          connection_id: connection.id
        )

        repository2 = build(:ai_active_context_code_repository,
          project: create(:project),
          enabled_namespace: enabled_namespace,
          connection_id: connection.id
        )

        expect(repository2).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.for_connection_and_enabled_namespace' do
      let_it_be(:connection1) { create(:ai_active_context_connection) }
      let_it_be(:connection2) { create(:ai_active_context_connection, :inactive) }
      let_it_be(:enabled_namespace1) do
        create(:ai_active_context_code_enabled_namespace, active_context_connection: connection1)
      end

      let_it_be(:enabled_namespace2) do
        create(:ai_active_context_code_enabled_namespace, active_context_connection: connection2)
      end

      let_it_be(:repository1) do
        create(:ai_active_context_code_repository, enabled_namespace: enabled_namespace1,
          active_context_connection: connection1)
      end

      let_it_be(:repository2) do
        create(:ai_active_context_code_repository, enabled_namespace: enabled_namespace2,
          active_context_connection: connection2)
      end

      let_it_be(:repository3) do
        create(:ai_active_context_code_repository, enabled_namespace: enabled_namespace1,
          active_context_connection: connection1)
      end

      it 'returns repositories for the specified connection and enabled namespace' do
        result = described_class.for_connection_and_enabled_namespace(connection1, enabled_namespace1)

        expect(result).to contain_exactly(repository1, repository3)
      end
    end

    describe '.with_active_connection' do
      let_it_be(:active_connection) { create(:ai_active_context_connection) }
      let_it_be(:inactive_connection) { create(:ai_active_context_connection, :inactive) }
      let_it_be(:repository_with_active_connection) do
        create(:ai_active_context_code_repository, active_context_connection: active_connection)
      end

      let_it_be(:repository_with_inactive_connection) do
        create(:ai_active_context_code_repository, active_context_connection: inactive_connection)
      end

      it 'returns repositories with active connections' do
        result = described_class.with_active_connection

        expect(result).to contain_exactly(repository_with_active_connection)
      end
    end
  end

  describe 'table partitioning' do
    it 'is partitioned by project_id' do
      expect(described_class.partitioning_strategy).to be_a(Gitlab::Database::Partitioning::IntRangeStrategy)
      expect(described_class.partitioning_strategy.partitioning_key).to eq(:project_id)
    end
  end

  describe 'foreign key constraints' do
    describe 'when enabled_namespace is deleted' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let!(:model) { create(:ai_active_context_code_repository) }
        let!(:parent) { model.enabled_namespace }
      end
    end

    describe 'when project is deleted' do
      it_behaves_like 'update by a loose foreign key' do
        let_it_be(:model) { create(:ai_active_context_code_repository) }
        let!(:parent) { model.project }
      end
    end

    describe 'when connection is deleted' do
      it 'sets connection_id and enabled_namespace_id to nil but keeps the repository record' do
        expect(repository.connection_id).to eq(connection.id)

        connection.destroy!
        repository.reload

        expect(repository).to be_persisted
        expect(repository.project_id).to eq(project.id)
        expect(repository.connection_id).to be_nil
      end
    end
  end
end
