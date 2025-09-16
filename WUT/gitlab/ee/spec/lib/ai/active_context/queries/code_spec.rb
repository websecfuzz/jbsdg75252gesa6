# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Queries::Code, feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let(:search_term) { 'dummy search term' }

  subject(:codebase_query) { described_class.new(search_term: search_term, user: user) }

  describe '#filter' do
    let_it_be(:project) { create(:project, owners: [user]) }

    context 'when code collection record does not exist' do
      let(:expected_error_class) { Ai::ActiveContext::Queries::Code::NoCollectionRecordError }

      it 'raises the expected error' do
        expect { codebase_query.filter(project_id: project.id) }.to raise_error(
          expected_error_class, "A Code collection record is required."
        )
      end
    end

    context 'when a code collection record exists' do
      before do
        # We get the embeddings version and details from Ai::ActiveContext::Collections::Code::MODELS
        embeddings_version = 1
        embeddings_version_details = Ai::ActiveContext::Collections::Code::MODELS[1]

        create(
          :ai_active_context_collection,
          name: Ai::ActiveContext::Collections::Code.collection_name,
          search_embedding_version: embeddings_version,
          include_ref_fields: false
        )

        # mock the call to embeddings generation
        allow(ActiveContext::Embeddings).to receive(:generate_embeddings)
          .with(
            search_term,
            unit_primitive: 'generate_embeddings_codebase',
            version: embeddings_version_details
          ).and_return([target_embeddings])

        # mock code collections search, with different results depending on project_id
        allow(::Ai::ActiveContext::Collections::Code).to receive(:search) do |args|
          project_id = args[:query].children.first.children.first.value[:project_id]

          es_docs = elasticsearch_docs[project_id]
          build_es_query_result(es_docs)
        end
      end

      let_it_be(:project_2) { create(:project, developers: [user]) }

      let(:target_embeddings) { [1, 2, 3] }

      let(:elasticsearch_docs) do
        {
          project.id => [
            { '_source' => { 'id' => 1, 'project_id' => project.id, 'content' => "test content 1-1" } },
            { '_source' => { 'id' => 1, 'project_id' => project.id, 'content' => "test content 1-2" } }
          ],
          project_2.id => [
            { '_source' => { 'id' => 2, 'project_id' => project_2.id, 'content' => "test content 2-1" } }
          ]
        }
      end

      it 'generates embeddings only once for multiple filters' do
        expect(ActiveContext::Embeddings).to receive(:generate_embeddings).once

        codebase_query.filter(project_id: project.id)
        codebase_query.filter(project_id: project_2.id)
      end

      it 'calls a search on the Code collection class for each filter' do
        expect(::Ai::ActiveContext::Collections::Code).to receive(:search).twice

        codebase_query.filter(project_id: project.id)
        codebase_query.filter(project_id: project_2.id)
      end

      it 'returns the expected results' do
        project_1_results = codebase_query.filter(project_id: project.id)
        expect(project_1_results.each.to_a).to eq(elasticsearch_docs[project.id].pluck('_source'))

        project_2_results = codebase_query.filter(project_id: project_2.id)
        expect(project_2_results.each.to_a).to eq(elasticsearch_docs[project_2.id].pluck('_source'))
      end

      context 'when filtering by path' do
        let(:project_es_docs_in_path) do
          [
            { '_source' => { 'id' => 1, 'project_id' => project.id, 'content' => "test content in path" } }
          ]
        end

        it 'passes the correct query parameters to search and returns the expected results' do
          allow(::Ai::ActiveContext::Collections::Code).to receive(:search) do |args|
            and_query = args[:query].children.first.children.first.children
            first_query = and_query.first
            second_query = and_query.second

            expect(first_query.type).to eq(:filter)
            expect(first_query.value).to eq({ project_id: project.id })

            expect(second_query.type).to eq(:prefix)
            expect(second_query.value).to eq({ path: 'some/path/' })

            # make sure to return query results
            build_es_query_result(project_es_docs_in_path)
          end

          results = codebase_query.filter(project_id: project.id, path: 'some/path')
          expect(results.each.to_a).to eq(project_es_docs_in_path.pluck('_source'))
        end
      end
    end
  end

  def build_es_query_result(es_docs)
    return unless es_docs

    es_hits = { 'hits' => { 'total' => { 'value' => 1 }, 'hits' => es_docs } }

    ActiveContext::Databases::Elasticsearch::QueryResult.new(
      result: es_hits,
      collection: Ai::ActiveContext::Collections::Code,
      user: user
    )
  end
end
