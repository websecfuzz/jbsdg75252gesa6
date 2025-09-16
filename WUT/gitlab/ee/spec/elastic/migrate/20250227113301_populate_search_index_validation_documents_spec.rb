# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250227113301_populate_search_index_validation_documents.rb')

RSpec.describe PopulateSearchIndexValidationDocuments, feature_category: :global_search do
  let(:version) { 20250227113301 }
  let(:migration) { described_class.new(version) }
  let(:index_validation_service) { ::Search::ClusterHealthCheck::IndexValidationService }

  describe '#migrate' do
    it 'calls the IndexValidationService execute method and stores the result' do
      expect(index_validation_service).to receive(:execute).once.and_return(true)
      expect(migration).to receive(:set_migration_state).with(service_result: true)

      migration.migrate
    end
  end

  describe '#completed?' do
    it 'always returns true' do
      expect(migration.completed?).to be true
    end
  end

  # Test the actual integration with the service
  describe 'integration with IndexValidationService' do
    context 'when service execution succeeds' do
      before do
        allow(index_validation_service).to receive(:execute).and_return(true)
        allow(migration).to receive(:set_migration_state)
      end

      it 'successfully completes the migration and stores the result' do
        expect(migration).to receive(:set_migration_state).with(service_result: true)
        migration.migrate
        expect(migration.completed?).to be true
      end
    end

    context 'when service execution fails' do
      before do
        allow(index_validation_service).to receive(:execute).and_return(false)
        allow(migration).to receive(:set_migration_state)
      end

      it 'still marks the migration as completed and stores the result' do
        expect(migration).to receive(:set_migration_state).with(service_result: false)
        migration.migrate
        expect(migration.completed?).to be true
      end
    end
  end
end
