# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Gitlab::Search::Client, feature_category: :global_search do
  let(:adapter) { ::Gitlab::Elastic::Helper.default.client }

  subject(:client) { described_class.new(adapter: adapter) }

  it 'delegates to adapter', :aggregate_failures do
    described_class::DELEGATED_METHODS.each do |msg|
      expect(client).to respond_to(msg)
      expect(adapter).to receive(msg)
      client.send(msg)
    end
  end

  describe '.execute_search' do
    let(:adapter) { described_class.search_adapter }
    let(:options) { { klass: Project } }
    let(:query) { { foo: 'bar' } }

    it 'calls search with the expected query' do
      expect(adapter).to receive(:search)
        .with(a_hash_including(timeout: '30s', index: Project.index_name, body: { foo: 'bar' })).and_return(true)

      described_class.execute_search(query: query, options: options) do |response|
        expect(response).to eq(true)
      end
    end

    context 'when count_only is set to true in options' do
      let(:options) { { klass: Project, count_only: true } }

      it 'calls search with the expected query' do
        expect(adapter).to receive(:search)
          .with(a_hash_including(timeout: '1s', index: Project.index_name, body: { foo: 'bar' })).and_return(true)

        described_class.execute_search(query: query, options: options) do |response|
          expect(response).to eq(true)
        end
      end
    end

    context 'when index_name is set to in options' do
      let(:options) { { index_name: 'foo-bar', count_only: true } }

      it 'calls search with the expected query' do
        expect(adapter).to receive(:search)
          .with(a_hash_including(timeout: '1s', index: 'foo-bar', body: { foo: 'bar' })).and_return(true)

        described_class.execute_search(query: query, options: options) do |response|
          expect(response).to eq(true)
        end
      end
    end

    context 'when retry_on_failure is set' do
      let(:retry_on_failure) { 3 }

      before do
        stub_application_setting(elasticsearch_retry_on_failure: retry_on_failure)
      end

      it 'calls search with the expected query' do
        expect(adapter).to receive(:search)
          .with(a_hash_including(timeout: '30s', index: Project.index_name, body: { foo: 'bar' })).and_return(true)

        described_class.execute_search(query: query, options: options) do |response|
          expect(response).to eq(true)
        end
      end

      it 'has the correct retry_on_failure option' do
        expect(adapter.transport.transport.options[:retry_on_failure]).to eq(retry_on_failure)
      end
    end
  end

  describe '.execute_count' do
    let(:adapter) { described_class.search_adapter }
    let(:options) { { klass: Project } }
    let(:query) { { query: {} } }

    it 'calls count with the expected query' do
      expect(adapter).to receive(:count)
                           .with(a_hash_including(index: Project.index_name, body: query))
                           .and_return(true)

      described_class.execute_count(query: query, options: options) do |response|
        expect(response).to eq(true)
      end
    end
  end
end
