# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250528090312_backfill_work_item_embeddings_gitlab.rb')

RSpec.describe BackfillWorkItemEmbeddingsGitlab, feature_category: :global_search do
  include DuoChatFixtureHelpers

  let(:version) { 20250528090312 }
  let(:migration) { described_class.new(version) }
  let_it_be(:embedding) { vertex_embedding_fixture }
  let_it_be(:project) { create(:project, :public) }
  let(:objects) { create_list(:work_item, 3, project: project) }
  let(:expected_fields) do
    {
      embedding_1: vertex_embedding_fixture
    }
  end

  let(:expected_throttle_delay) { 1.minute }
  let(:expected_batch_size) { 200 }

  before do
    skip 'vectors are not supported' unless Gitlab::Elastic::Helper.default.vectors_supported?(:elasticsearch)

    allow_next_instance_of(Gitlab::Llm::VertexAi::Embeddings::Text) do |instance|
      allow(instance).to receive(:execute).and_return(embedding)
    end

    stub_const("#{described_class}::PROJECT_IDS", [project.id])
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(true)
  end

  describe 'skip_migration?' do
    before do
      allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(available)
      described_class.skip_if -> { !Gitlab::Saas.feature_available?(:ai_vertex_embeddings) }
    end

    context 'if feature is available' do
      let(:available) { true }

      it 'returns false' do
        expect(migration.skip_migration?).to be_falsey
      end
    end

    context 'if feature is not available' do
      let(:available) { false }

      it 'returns true' do
        expect(migration.skip_migration?).to be_truthy
      end
    end
  end

  describe 'migration process', :elastic_delete_by_query do
    describe '#space_required_bytes' do
      let(:space_required_bytes) { migration.space_required_bytes }

      before do
        set_elasticsearch_migration_to(version, including: false)

        # ensure objects are indexed
        objects
        ensure_elasticsearch_index!
        remove_field_from_objects(objects)
      end

      it 'returns space required' do
        # 768 vectors * 4 bytes per vector * 3 documents
        expect(space_required_bytes).to eq(9_216)
      end
    end

    it_behaves_like 'migration backfills fields' do
      let(:bookkeeping_service) { Search::Elastic::ProcessEmbeddingBookkeepingService }

      before do
        objects
      end
    end
  end

  def add_field_for_objects(objects)
    source_script = expected_fields.map do |field_name, _|
      "ctx._source['#{field_name}'] = params.#{field_name};"
    end.join

    script =  {
      source: source_script,
      lang: "painless",
      params: expected_fields
    }

    update_by_query(objects, script)
  end

  def remove_field_from_objects(objects)
    source_script = expected_fields.map do |field_name, _|
      "ctx._source.remove('#{field_name}');"
    end.join

    script = {
      source: source_script
    }

    update_by_query(objects, script)
  end

  def update_by_query(objects, script)
    object_ids = objects.map(&:id)

    client = WorkItem.__elasticsearch__.client
    client.update_by_query(
      index: Search::Elastic::Types::WorkItem.index_name,
      wait_for_completion: true, # run synchronously
      refresh: true, # make operation visible to search
      body: {
        script: script,
        query: {
          bool: {
            must: [
              {
                terms: {
                  id: object_ids
                }
              }
            ]
          }
        }
      }
    )
  end
end
