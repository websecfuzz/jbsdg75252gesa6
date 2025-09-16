# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::Embedding, :elastic_helpers, feature_category: :global_search do
  let_it_be(:project) { create(:project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let(:routing) { issue.es_parent }
  let(:embedding_ref) { described_class.new(Issue, issue.id, routing) }
  let(:embedding_ref_serialized) { "Embedding|Issue|#{issue.id}|#{routing}" }
  let(:work_item_embedding_ref) { described_class.new(WorkItem, issue.id, routing) }

  before do
    allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(false)
  end

  it 'inherits from Reference' do
    expect(described_class.ancestors).to include(Search::Elastic::Reference)
  end

  describe '.serialize' do
    it 'builds a string with model klass, identifier and routing' do
      expect(described_class.serialize(issue)).to eq(embedding_ref_serialized)
    end
  end

  describe '.ref' do
    it 'returns an instance of embedding reference when given a record' do
      ref = described_class.ref(issue)

      expect(ref).to be_an_instance_of(described_class)
      expect(ref.model_klass).to eq(Issue)
      expect(ref.identifier).to eq(issue.id)
      expect(ref.routing).to eq(routing)
    end
  end

  describe '.instantiate' do
    it 'returns an instance of embedding reference when given a serialized string' do
      ref = described_class.instantiate(embedding_ref_serialized)

      expect(ref).to be_an_instance_of(described_class)
      expect(ref.model_klass).to eq(Issue)
      expect(ref.identifier).to eq(issue.id)
      expect(ref.routing).to eq(routing)
    end
  end

  describe '.preload_indexing_data' do
    let_it_be(:project2) { create(:project) }
    let_it_be(:issue2) { create(:issue, project: project2) }
    let(:embedding_ref2) { described_class.new(WorkItem, issue2.id, "project_#{project2.id}") }
    let(:embedding_ref3) { described_class.new(Issue, issue2.id, "project_#{project2.id}") }
    let(:embedding_ref4) { described_class.new(WorkItem, issue.id, "project_#{project.id}") }

    it 'preloads database records to avoid N+1 queries' do
      refs = []
      [embedding_ref, embedding_ref2].each do |ref|
        refs << Search::Elastic::Reference.deserialize(ref.serialize)
      end

      control = ActiveRecord::QueryRecorder.new { described_class.preload_indexing_data(refs).map(&:database_record) }

      refs = []
      [embedding_ref, embedding_ref2, embedding_ref3, embedding_ref4].each do |ref|
        refs << Search::Elastic::Reference.deserialize(ref.serialize)
      end

      database_records = nil
      expect do
        database_records = described_class.preload_indexing_data(refs).map(&:database_record)
      end.not_to exceed_query_limit(control)

      expect(database_records[0]).to eq(issue)
      expect(database_records[2]).to eq(issue2)
    end

    it 'calls preload in batches not to overload the database' do
      stub_const('Search::Elastic::Concerns::DatabaseClassReference::BATCH_SIZE', 1)
      refs = [embedding_ref, embedding_ref2]

      expect(Issue).to receive(:preload_indexing_data).and_call_original.once
      expect(WorkItem).to receive(:preload_indexing_data).and_call_original.once

      described_class.preload_indexing_data(refs)
    end
  end

  describe '#serialize' do
    it 'returns a delimited string' do
      expect(embedding_ref.serialize).to eq(embedding_ref_serialized)
    end
  end

  describe '#as_indexed_json' do
    let(:embedding_service) { instance_double(Gitlab::Llm::VertexAi::Embeddings::Text) }
    let(:mock_embedding) { [1, 2, 3] }
    let(:model) { 'text-embedding-005' }

    before do
      allow(Gitlab::Llm::VertexAi::Embeddings::Text).to receive(:new).and_return(embedding_service)
      allow(embedding_service).to receive(:execute).and_return(mock_embedding)
    end

    it 'returns the embedding and its version' do
      expect(work_item_embedding_ref.as_indexed_json).to eq({ embedding_0: mock_embedding, routing: routing })
    end

    it 'calls embedding API' do
      content = "work item of type 'Issue' with title '#{issue.title}' and description '#{issue.description}'"
      tracking_context = { action: 'work_item_embedding' }
      primitive = 'semantic_search_issue'

      expect(Gitlab::Llm::VertexAi::Embeddings::Text)
        .to receive(:new)
        .with(content, user: nil, tracking_context: tracking_context, unit_primitive: primitive, model: nil)
        .and_return(embedding_service)

      work_item_embedding_ref.as_indexed_json
    end

    context 'when model_klass is work_item' do
      let(:content) { "work item of type 'Issue' with title '#{issue.title}' and description '#{issue.description}'" }
      let(:tracking_context) { { action: 'work_item_embedding' } }
      let(:primitive) { 'semantic_search_issue' }

      it 'returns the embedding and its version' do
        expect(work_item_embedding_ref.as_indexed_json).to eq({ embedding_0: mock_embedding, routing: routing })
      end

      it 'calls embedding API' do
        expect(Gitlab::Llm::VertexAi::Embeddings::Text)
          .to receive(:new)
          .with(content, user: nil, tracking_context: tracking_context, unit_primitive: primitive, model: nil)
          .and_return(embedding_service)

        expect(work_item_embedding_ref.as_indexed_json.keys).to match_array([:routing, :embedding_0])
      end

      context 'when embedding_1 migration is added to Elasticsearch' do
        before do
          set_elasticsearch_migration_to :add_embedding1_to_work_items_elastic, including: true
        end

        it 'calls embedding API with custom model' do
          expect(Gitlab::Llm::VertexAi::Embeddings::Text)
            .to receive(:new)
            .with(content, user: nil, tracking_context: tracking_context, unit_primitive: primitive, model: model)
            .and_return(embedding_service)

          expect(work_item_embedding_ref.as_indexed_json.keys).to match_array([:routing, :embedding_0, :embedding_1])
        end

        context 'when backfill_work_items_embeddings1 migration is complete' do
          before do
            set_elasticsearch_migration_to :backfill_work_items_embeddings1, including: true
          end

          it 'does not set embedding_0' do
            expect(work_item_embedding_ref.as_indexed_json.keys).to match_array([:routing, :embedding_1])
          end
        end
      end

      context 'when embedding_1 migration is added to OpenSearch' do
        before do
          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
            .with(:add_embedding1_to_work_items_open_search).and_return(true)
        end

        it 'calls embedding API with custom model' do
          expect(Gitlab::Llm::VertexAi::Embeddings::Text)
            .to receive(:new)
            .with(content, user: nil, tracking_context: tracking_context, unit_primitive: primitive, model: model)
            .and_return(embedding_service)

          expect(work_item_embedding_ref.as_indexed_json.keys).to match_array([:routing, :embedding_0, :embedding_1])
        end

        context 'when backfill_work_items_embeddings1 migration is complete' do
          before do
            allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
              .with(:backfill_work_items_embeddings1).and_return(true)
          end

          it 'does not set embedding_0' do
            expect(work_item_embedding_ref.as_indexed_json.keys).to match_array([:routing, :embedding_1])
          end
        end
      end
    end

    context 'when model_klass does not have a definition' do
      it 'raises a ReferenceFailure error' do
        other_embedding_ref = described_class.new(Note, issue.id, routing)
        msg = 'Unknown as_indexed_json definition for model class: Note'
        expect { other_embedding_ref.as_indexed_json }.to raise_error(Search::Elastic::Reference::ReferenceFailure, msg)
      end
    end

    context 'if the endpoint is throttled' do
      before do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)
      end

      it 'raises a ReferenceFailure error' do
        message = "Failed to generate embedding: Rate limited endpoint 'vertex_embeddings_api' is throttled"
        expect { work_item_embedding_ref.as_indexed_json }
          .to raise_error(::Search::Elastic::Reference::ReferenceFailure, message)
      end
    end

    context 'if an error is raised' do
      before do
        allow(embedding_service).to receive(:execute).and_raise(StandardError, 'error')
      end

      it 'raises a ReferenceFailure error' do
        message = 'Failed to generate embedding: error'
        expect { work_item_embedding_ref.as_indexed_json }
          .to raise_error(::Search::Elastic::Reference::ReferenceFailure, message)
      end
    end
  end

  describe '#operation' do
    it 'is upsert' do
      expect(embedding_ref.operation).to eq(:upsert)
    end

    context 'when the database record does not exist' do
      before do
        allow(embedding_ref).to receive(:database_record).and_return(nil)
      end

      it 'is delete' do
        expect(embedding_ref.operation).to eq(:delete)
      end
    end
  end

  describe '#index_name' do
    it 'is equal to proxy index name' do
      expect(embedding_ref.index_name).to eq('gitlab-test-issues')
    end

    context 'if type class exists' do
      it 'is equal type class index name' do
        expect(work_item_embedding_ref.index_name).to eq('gitlab-test-work_items')
      end
    end
  end
end
