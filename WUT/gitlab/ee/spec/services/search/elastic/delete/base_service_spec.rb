# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Delete::BaseService, feature_category: :global_search do
  let(:options) { { project_id: 123, some_key: 'value' } }
  let(:service) { described_class.new(options) }
  let(:mock_client) { instance_double(Gitlab::Search::Client) }
  let(:mock_logger) { instance_double(Gitlab::Elasticsearch::Logger) }

  before do
    allow(service).to receive_messages(build_query: { query: { term: { project_id: 123 } } },
      index_name: 'test_index',
      client: mock_client,
      logger: mock_logger)
    allow(Gitlab::Search::Client).to receive(:new).and_return(mock_client)
    allow(Gitlab::Elasticsearch::Logger).to receive(:build).and_return(mock_logger)
  end

  describe '.execute' do
    it 'instantiates the service and calls execute' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(options)
    end
  end

  describe '#initialize' do
    it 'sets options with indifferent access' do
      expect(service.send(:options)).to be_a(ActiveSupport::HashWithIndifferentAccess)
      expect(service.send(:options)[:project_id]).to eq(123)
      expect(service.send(:options)['project_id']).to eq(123)
    end
  end

  describe '#execute' do
    it 'calls remove_documents' do
      expect(service).to receive(:remove_documents)
      service.execute
    end
  end

  describe '#remove_documents' do
    context 'when build_query returns blank' do
      before do
        allow(service).to receive(:build_query).and_return(nil)
      end

      it 'returns early without calling the client' do
        expect(mock_client).not_to receive(:delete_by_query)
        service.send(:remove_documents)
      end
    end

    context 'when build_query returns a query' do
      let(:query) { { query: { term: { project_id: 123 } } } }
      let(:response) { { 'deleted' => 5 } }

      before do
        allow(service).to receive(:build_query).and_return(query)
      end

      it 'calls delete_by_query with correct parameters' do
        expect(mock_client).to receive(:delete_by_query).with({
          index: 'test_index',
          conflicts: 'proceed',
          timeout: described_class::QUERY_TIMEOUT,
          body: query
        }).and_return(response)

        expect(mock_logger).to receive(:info).with(hash_including(
          'deleted' => 5,
          'message' => 'Successfully deleted documents',
          'index' => 'test_index'
        ))

        service.send(:remove_documents)
      end

      context 'when delete operation fails' do
        let(:failure_response) { { 'failure' => ['error'], 'deleted' => 0 } }

        it 'logs the error' do
          expect(mock_client).to receive(:delete_by_query).and_return(failure_response)
          expect(mock_logger).to receive(:error).with(hash_including(
            'failure' => ['error'],
            'message' => 'Failed to delete documents',
            'index' => 'test_index'
          ))

          service.send(:remove_documents)
        end
      end
    end
  end

  describe '#build_query' do
    it 'raises NotImplementedError' do
      allow(service).to receive(:build_query).and_call_original

      expect { service.send(:build_query) }.to raise_error(NotImplementedError)
    end
  end

  describe '#index_name' do
    it 'raises NotImplementedError' do
      allow(service).to receive(:index_name).and_call_original

      expect { service.send(:index_name) }.to raise_error(NotImplementedError)
    end
  end
end
