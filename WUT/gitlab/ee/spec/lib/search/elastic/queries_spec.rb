# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Queries, feature_category: :global_search do
  describe '#by_iid' do
    subject(:by_iid) { described_class.by_iid(iid: 1, doc_type: 'my_type') }

    it 'returns the expected query hash' do
      expected_filter = [
        { term: { iid: { _name: 'my_type:related:iid', value: 1 } } },
        { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
      ]

      expect(by_iid[:query][:bool][:must]).to eq([])
      expect(by_iid[:query][:bool][:must_not]).to eq([])
      expect(by_iid[:query][:bool][:should]).to eq([])
      expect(by_iid[:query][:bool][:filter]).to eq(expected_filter)
    end
  end

  describe '#by_full_text' do
    let(:query) { 'foo bar' }
    let(:options) { { fields: %w[iid^3 title^2 description] } }

    subject(:by_full_text) do
      described_class.by_full_text(query: query, options: options)
    end

    context 'when advanced query syntax is not matched' do
      it 'calls by_multi_match_query' do
        expect(described_class).to receive(:by_multi_match_query).with(fields: options[:fields], query: query,
          options: options)
        by_full_text
      end
    end

    context 'when advanced query syntax is matched' do
      let(:query) { 'foo ~bar' }

      it 'calls by_simple_query_string' do
        expect(described_class).to receive(:by_simple_query_string).with(fields: options[:fields], query: query,
          options: options)
        by_full_text
      end
    end
  end

  describe '#by_simple_query_string' do
    let(:query) { 'foo bar' }
    let(:options) { base_options }
    let(:base_options) { { doc_type: 'my_type' } }
    let(:fields) { %w[iid^3 title^2 description] }

    subject(:by_simple_query_string) do
      described_class.by_simple_query_string(fields: fields, query: query, options: options)
    end

    context 'when custom elasticsearch analyzers are enabled' do
      before do
        stub_ee_application_setting(elasticsearch_analyzers_smartcn_enabled: true,
          elasticsearch_analyzers_smartcn_search: true)
      end

      it 'applies custom analyzer fields' do
        expected_must = [
          { simple_query_string: { _name: 'my_type:match:search_terms',
                                   fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                                   query: 'foo bar', lenient: true, default_operator: :and } }
        ]

        expect(by_simple_query_string[:query][:bool][:must]).to eql(expected_must)
      end

      context 'when fields is a frozen array' do
        let(:fields) { %w[iid^3 title^2 description].freeze }

        it 'applies custom analyzer fields' do
          expected_must = [
            { simple_query_string: { _name: 'my_type:match:search_terms',
                                     fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                                     query: 'foo bar', lenient: true, default_operator: :and } }
          ]

          expect(by_simple_query_string[:query][:bool][:must]).to eql(expected_must)
        end
      end
    end

    it 'applies highlight in query' do
      expected = { fields: { iid: {}, title: {}, description: {} },
                   number_of_fragments: 0, pre_tags: ['gitlabelasticsearch→'], post_tags: ['←gitlabelasticsearch'] }

      expect(by_simple_query_string[:highlight]).to eq(expected)
    end

    context 'when options[:clause] is should' do
      let(:options) { base_options.merge(keyword_match_clause: :should) }

      it 'returns a simple_query_string query as a should and adds doc type as a filter' do
        expected_should = [
          { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid^3 title^2 description],
                                   query: 'foo bar', lenient: true, default_operator: :and } }
        ]
        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
        ]

        expect(by_simple_query_string[:query][:bool][:must]).to eq([])
        expect(by_simple_query_string[:query][:bool][:must_not]).to eq([])
        expect(by_simple_query_string[:query][:bool][:should]).to eq(expected_should)
        expect(by_simple_query_string[:query][:bool][:filter]).to eq(expected_filter)
      end
    end

    context 'when options[:related_ids] are provided' do
      let(:options) { base_options.merge(related_ids: [12, 14]) }

      it 'returns a simple_query_string query and an id query in should array and adds doc type as a filter' do
        expected_should = [
          { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid^3 title^2 description],
                                   query: 'foo bar', lenient: true, default_operator: :and } },
          { terms: { _name: 'my_type:related:ids', id: [12, 14],
                     boost: Search::Elastic::Queries::DEFAULT_RELATED_ID_BOOST } }
        ]
        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
        ]

        expect(by_simple_query_string[:query][:bool][:must]).to eq([])
        expect(by_simple_query_string[:query][:bool][:must_not]).to eq([])
        expect(by_simple_query_string[:query][:bool][:should]).to eq(expected_should)
        expect(by_simple_query_string[:query][:bool][:filter]).to eq(expected_filter)
      end

      context 'when options[:related_ids_boost] is also provided' do
        let(:options) { base_options.merge(related_ids: [12, 14], related_ids_boost: 12) }

        it 'uses the boost in the id query' do
          expected_should = [
            { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid^3 title^2 description],
                                     query: 'foo bar', lenient: true, default_operator: :and } },
            { terms: { _name: 'my_type:related:ids', id: [12, 14], boost: 12 } }
          ]
          expected_filter = [
            { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
          ]

          expect(by_simple_query_string[:query][:bool][:must]).to eq([])
          expect(by_simple_query_string[:query][:bool][:must_not]).to eq([])
          expect(by_simple_query_string[:query][:bool][:should]).to eq(expected_should)
          expect(by_simple_query_string[:query][:bool][:filter]).to eq(expected_filter)
        end
      end
    end

    context 'when query is provided' do
      it 'returns a simple_query_string query as a must and adds doc type as a filter' do
        expected_must = [
          { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid^3 title^2 description],
                                   query: 'foo bar', lenient: true, default_operator: :and } }
        ]
        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
        ]

        expect(by_simple_query_string[:query][:bool][:must]).to eq(expected_must)
        expect(by_simple_query_string[:query][:bool][:must_not]).to eq([])
        expect(by_simple_query_string[:query][:bool][:should]).to eq([])
        expect(by_simple_query_string[:query][:bool][:filter]).to eq(expected_filter)
      end
    end

    context 'when query is not provided' do
      let(:query) { nil }

      it 'returns a match_all query' do
        expected_must = { match_all: {} }

        expect(by_simple_query_string[:query][:bool][:must]).to eq(expected_must)
        expect(by_simple_query_string[:query][:bool][:must_not]).to eq([])
        expect(by_simple_query_string[:query][:bool][:should]).to eq([])
        expect(by_simple_query_string[:query][:bool][:filter]).to eq([])
        expect(by_simple_query_string[:track_scores]).to be(true)
      end
    end

    context 'when options[:count_only] is true' do
      let(:options) { base_options.merge(count_only: true) }

      it 'does not apply highlight in query' do
        expect(by_simple_query_string[:highlight]).to be_nil
      end

      it 'removes field boosts and returns a simple_query_string as a filter' do
        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } },
          { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid title description],
                                   query: 'foo bar', lenient: true, default_operator: :and } }
        ]

        expect(by_simple_query_string[:query][:bool][:must]).to eq([])
        expect(by_simple_query_string[:query][:bool][:must_not]).to eq([])
        expect(by_simple_query_string[:query][:bool][:should]).to eq([])
        expect(by_simple_query_string[:query][:bool][:filter]).to eq(expected_filter)
      end
    end
  end

  describe '#by_multi_match_query' do
    let(:query) { 'foo bar' }
    let(:options) { base_options }
    let(:base_options) { { doc_type: 'my_type' } }
    let(:fields) { %w[iid^3 title^2 description] }

    subject(:by_multi_match_query) do
      described_class.by_multi_match_query(fields: fields, query: query, options: options)
    end

    context 'when custom elasticsearch analyzers are enabled' do
      before do
        stub_ee_application_setting(elasticsearch_analyzers_smartcn_enabled: true,
          elasticsearch_analyzers_smartcn_search: true)
      end

      it 'applies custom analyzer fields to multi_match_query' do
        expected_must = [{ bool: {
          should: [
            { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                             fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                             query: 'foo bar', operator: :and, lenient: true } },
            { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                             type: :phrase, fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                             query: 'foo bar', lenient: true } }
          ],
          minimum_should_match: 1
        } }]

        expect(by_multi_match_query[:query][:bool][:must]).to eql(expected_must)
      end

      context 'when fields is a frozen array' do
        let(:fields) { %w[iid^3 title^2 description].freeze }

        it 'applies custom analyzer fields to multi_match_query' do
          expected_must = [{ bool: {
            should: [
              { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                               fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                               query: 'foo bar', operator: :and, lenient: true } },
              { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                               type: :phrase, fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                               query: 'foo bar', lenient: true } }
            ],
            minimum_should_match: 1
          } }]

          expect(by_multi_match_query[:query][:bool][:must]).to eql(expected_must)
        end
      end
    end

    it 'applies highlight in query' do
      expected = { fields: { iid: {}, title: {}, description: {} },
                   number_of_fragments: 0, pre_tags: ['gitlabelasticsearch→'], post_tags: ['←gitlabelasticsearch'] }

      expect(by_multi_match_query[:highlight]).to eq(expected)
    end

    context 'when query is provided' do
      it 'returns a by_multi_match_query query as a should and adds doc type as a filter' do
        expected_must = [{ bool: {
          should: [
            { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                             fields: %w[iid^3 title^2 description],
                             query: 'foo bar', operator: :and, lenient: true } },
            { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                             type: :phrase, fields: %w[iid^3 title^2 description],
                             query: 'foo bar', lenient: true } }
          ],
          minimum_should_match: 1
        } }]

        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
        ]

        expect(by_multi_match_query[:query][:bool][:must]).to eql(expected_must)
        expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
        expect(by_multi_match_query[:query][:bool][:should]).to eq([])
        expect(by_multi_match_query[:query][:bool][:filter]).to eq(expected_filter)
      end
    end

    context 'when query is not provided' do
      let(:query) { nil }

      it 'returns a match_all query' do
        expected_must = { match_all: {} }

        expect(by_multi_match_query[:query][:bool][:must]).to eq(expected_must)
        expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
        expect(by_multi_match_query[:query][:bool][:should]).to eq([])
        expect(by_multi_match_query[:query][:bool][:filter]).to eq([])
        expect(by_multi_match_query[:track_scores]).to be(true)
      end
    end

    context 'when options[:clause] is should' do
      let(:options) { base_options.merge(keyword_match_clause: :should) }

      it 'removes field boosts and returns a by_multi_match_query as a filter' do
        expected_should = [
          { bool: {
            should: [
              { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                               fields: %w[iid^3 title^2 description],
                               query: 'foo bar', operator: :and, lenient: true } },
              { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                               type: :phrase, fields: %w[iid^3 title^2 description],
                               query: 'foo bar', lenient: true } }
            ],
            minimum_should_match: 1
          } }
        ]

        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
        ]
        expect(by_multi_match_query[:query][:bool][:must]).to eq([])
        expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
        expect(by_multi_match_query[:query][:bool][:should]).to eql(expected_should)
        expect(by_multi_match_query[:query][:bool][:filter]).to eql(expected_filter)
      end
    end

    context 'when options[:related_ids] is provided' do
      let(:options) { base_options.merge(related_ids: [12, 14]) }

      it 'returns a by_multi_match_query query and an id query in should array and adds doc type as a filter' do
        expected_should = [
          { bool: { minimum_should_match: 1,
                    should: [
                      { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                                       fields: %w[iid^3 title^2 description],
                                       query: 'foo bar', operator: :and, lenient: true } },
                      { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                                       type: :phrase, fields: %w[iid^3 title^2 description],
                                       query: 'foo bar', lenient: true } }
                    ] } },
          { terms: { _name: 'my_type:related:ids', id: [12, 14],
                     boost: Search::Elastic::Queries::DEFAULT_RELATED_ID_BOOST } }
        ]
        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
        ]

        expect(by_multi_match_query[:query][:bool][:must]).to be_empty
        expect(by_multi_match_query[:query][:bool][:must_not]).to be_empty
        expect(by_multi_match_query[:query][:bool][:should]).to eq(expected_should)
        expect(by_multi_match_query[:query][:bool][:filter]).to eq(expected_filter)
      end

      context 'when options[:related_ids_boost] is also provided' do
        let(:options) { base_options.merge(related_ids: [12, 14], related_ids_boost: 12) }

        it 'uses the boost in the id query' do
          expected_should = [
            { bool: { minimum_should_match: 1,
                      should: [
                        { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                                         fields: %w[iid^3 title^2 description],
                                         query: 'foo bar', operator: :and, lenient: true } },
                        { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                                         type: :phrase, fields: %w[iid^3 title^2 description],
                                         query: 'foo bar', lenient: true } }
                      ] } },
            { terms: { _name: 'my_type:related:ids', id: [12, 14], boost: 12 } }
          ]
          expected_filter = [
            { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
          ]

          expect(by_multi_match_query[:query][:bool][:must]).to be_empty
          expect(by_multi_match_query[:query][:bool][:must_not]).to be_empty
          expect(by_multi_match_query[:query][:bool][:should]).to eq(expected_should)
          expect(by_multi_match_query[:query][:bool][:filter]).to eq(expected_filter)
        end
      end
    end

    context 'when options[:count_only] is true' do
      let(:options) { base_options.merge(count_only: true) }

      it 'does not apply highlight in query' do
        expect(by_multi_match_query[:highlight]).to be_nil
      end

      it 'removes field boosts and returns a by_multi_match_query as a filter' do
        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } },
          { bool: {
            should: [
              { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                               fields: %w[iid title description],
                               query: 'foo bar', operator: :and, lenient: true } },
              { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                               type: :phrase, fields: %w[iid title description],
                               query: 'foo bar', lenient: true } }
            ],
            minimum_should_match: 1
          } }
        ]

        expect(by_multi_match_query[:query][:bool][:must]).to eq([])
        expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
        expect(by_multi_match_query[:query][:bool][:should]).to eq([])
        expect(by_multi_match_query[:query][:bool][:filter]).to eql(expected_filter)
      end
    end
  end

  describe '#by_knn' do
    let_it_be(:user) { create(:user) }
    let(:hybrid_similarity) { 0.5 }
    let(:hybrid_boost) { 0.9 }
    let(:options) do
      {
        current_user: user,
        hybrid_similarity: hybrid_similarity,
        hybrid_boost: hybrid_boost,
        embedding_field: :embedding_0,
        fields: %w[iid^3 title^2 description],
        vectors_supported: :elasticsearch
      }
    end

    let(:embedding_service) { instance_double(Gitlab::Llm::VertexAi::Embeddings::Text) }
    let(:mock_embedding) { [1, 2, 3] }

    subject(:by_knn) { described_class.by_knn(query: 'test', options: options) }

    before do
      allow(Gitlab::Llm::VertexAi::Embeddings::Text).to receive(:new).and_return(embedding_service)
      allow(embedding_service).to receive(:execute).and_return(mock_embedding)
    end

    it 'returns the expected query hash' do
      expect(by_knn).to have_key(:knn)
      expect(by_knn[:knn][:query_vector]).to eq(mock_embedding)
      expect(by_knn[:knn][:similarity]).to eq(hybrid_similarity)
      expect(by_knn[:knn][:boost]).to eq(hybrid_boost)
    end

    context 'if we do not pass hybrid_similarity and hybrid_boost' do
      let(:options) do
        {
          current_user: user,
          embedding_field: :embedding_0,
          fields: %w[iid^3 title^2 description],
          vectors_supported: :elasticsearch
        }
      end

      it 'uses default value' do
        expect(by_knn).to have_key(:knn)
        expect(by_knn[:knn][:query_vector]).to eq(mock_embedding)
        expect(by_knn[:knn][:similarity]).to eq(described_class::DEFAULT_HYBRID_SIMILARITY)
        expect(by_knn[:knn][:boost]).to eq(described_class::DEFAULT_HYBRID_BOOST)
      end
    end

    context 'if the embedding endpoint is throttled' do
      before do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)
      end

      it 'tracks the error and does not include the knn query' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)

        expect(by_knn).not_to have_key(:knn)
      end
    end

    context 'if an error is raised' do
      before do
        allow(embedding_service).to receive(:execute).and_raise(StandardError, 'error')
      end

      it 'tracks the error and does not include the knn query' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)

        expect(by_knn).not_to have_key(:knn)
      end
    end

    context 'when options[:vectors_supported] is falsy' do
      let(:options) do
        {
          current_user: user,
          embedding_field: :embedding_0,
          fields: %w[iid^3 title^2 description],
          vectors_supported: nil
        }
      end

      it 'falls back to by_full_text' do
        expect(described_class).to receive(:by_full_text).with(query: 'test', options: options)

        by_knn
      end
    end

    context 'when options[:vectors_supported] is not in ALLOWED_SEARCH_CLIENTS' do
      let(:options) do
        {
          current_user: user,
          embedding_field: :embedding_0,
          fields: %w[iid^3 title^2 description],
          vectors_supported: :invalid_client
        }
      end

      it 'raises ArgumentError' do
        expect { by_knn }.to raise_error(ArgumentError, 'Invalid search client')
      end
    end

    context 'when options[:vectors_supported] is opensearch' do
      let(:options) do
        {
          current_user: user,
          embedding_field: :embedding_0,
          fields: %w[iid^3 title^2 description],
          vectors_supported: :opensearch
        }
      end

      it 'builds opensearch knn query' do
        expect(by_knn.dig(:query, :bool, :should))
          .to include(a_hash_including(knn: { embedding_0: { k: 25, vector: mock_embedding } }))
      end

      it 'sets simple_query_string_boost and keyword_match_clause options' do
        expect(described_class).to receive(:by_full_text).with(
          query: 'test',
          options: hash_including(
            simple_query_string_boost: described_class::SIMPLE_QUERY_STRING_BOOST,
            keyword_match_clause: :should
          )
        ).and_call_original

        by_knn
      end
    end

    context 'when options[:vectors_supported] is elasticsearch' do
      let(:options) do
        {
          current_user: user,
          embedding_field: :embedding_0,
          fields: %w[iid^3 title^2 description],
          vectors_supported: :elasticsearch
        }
      end

      it 'builds elasticsearch knn query' do
        expect(by_knn[:knn]).to match(a_hash_including(
          field: 'embedding_0',
          query_vector: mock_embedding,
          boost: described_class::DEFAULT_HYBRID_BOOST,
          k: 25,
          num_candidates: 100,
          similarity: described_class::DEFAULT_HYBRID_SIMILARITY
        ))
      end
    end
  end
end
