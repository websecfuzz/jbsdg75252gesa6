# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250409103441_add_embedding1_to_work_items_open_search.rb')

RSpec.describe AddEmbedding1ToWorkItemsOpenSearch, feature_category: :global_search do
  let(:version) { 20250409103441 }
  let(:migration) { described_class.new(version) }
  let(:helper) { Gitlab::Elastic::Helper.default }

  before do
    allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
    allow(migration).to receive(:helper).and_return(helper)
  end

  describe 'migration', :elastic, :sidekiq_inline do
    before do
      skip 'migration is skipped' if migration.skip_migration?
    end

    describe '#new_mappings' do
      let(:opensearch_knn_field) { { type: 'knn_vector', dimension: 768 } }

      it 'returns embedding_1 field with opensearch_knn_field configuration' do
        allow(Search::Elastic::Types::WorkItem).to receive(:opensearch_knn_field).and_return(opensearch_knn_field)

        expect(migration.new_mappings).to eq({ embedding_1: opensearch_knn_field })
      end
    end

    describe '.migrate' do
      describe 'migration process' do
        before do
          allow(helper).to receive(:get_mapping).and_return({})
        end

        it 'updates the issues index mappings' do
          expect(helper).to receive(:update_mapping)

          migration.migrate
        end
      end
    end

    describe '.completed?' do
      context 'when mapping has not been updated' do
        before do
          allow(helper).to receive(:get_mapping).and_return({})
        end

        specify { expect(migration).not_to be_completed }
      end
    end
  end

  describe 'skip_migration?' do
    let(:helper) { Gitlab::Elastic::Helper.default }

    before do
      allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:vectors_supported?).and_return(vectors_supported)
      described_class.skip_if -> { !Gitlab::Elastic::Helper.default.vectors_supported?(:opensearch) }
    end

    context 'if vectors are supported' do
      let(:vectors_supported) { true }

      it 'returns false' do
        expect(migration.skip_migration?).to be_falsey
      end
    end

    context 'if vectors are not supported' do
      let(:vectors_supported) { false }

      it 'returns true' do
        expect(migration.skip_migration?).to be_truthy
      end
    end
  end
end
