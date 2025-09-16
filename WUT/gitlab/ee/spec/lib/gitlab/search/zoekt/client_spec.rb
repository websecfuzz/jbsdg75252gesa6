# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Search::Zoekt::Client, feature_category: :global_search do
  let_it_be(:project_1) { create(:project, :public, :repository) }
  let_it_be(:project_2) { create(:project, :public, :repository) }
  let_it_be(:project_3) { create(:project, :public, :repository) }
  let(:client) { described_class.new }

  before_all do
    zoekt_truncate_index!
    zoekt_ensure_project_indexed!(project_1)
    zoekt_ensure_project_indexed!(project_2)
    zoekt_ensure_project_indexed!(project_3)
  end

  after(:all) do
    zoekt_truncate_index!
  end

  shared_examples 'an authenticated zoekt request' do
    context 'when basicauth username and password are present' do
      let(:password_file) { Rails.root.join("tmp/tests/zoekt_password") }
      let(:username_file) { Rails.root.join("tmp/tests/zoekt_username") }

      before do
        username_file = Rails.root.join("tmp/tests/zoekt_username")
        File.write(username_file, "the-username\r") # Ensure trailing newline is ignored
        password_file = Rails.root.join("tmp/tests/zoekt_password")
        File.write(password_file, "the-password\r") # Ensure trailing newline is ignored
        stub_config(zoekt: { username_file: username_file, password_file: password_file })
      end

      after do
        File.delete(username_file)
        File.delete(password_file)
      end

      it 'sets those in the request' do
        expect(::Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(basic_auth: { username: 'the-username', password: 'the-password' }))
          .and_call_original

        make_request
      end
    end

    context 'when JWT authentication is enabled' do
      let(:auth_token) { 'test-jwt-token' }

      before do
        allow(Search::Zoekt::JwtAuth).to receive(:jwt_token).and_return(auth_token)
      end

      it 'includes JWT authorization header in the request' do
        headers = { described_class::JWT_HEADER => "Bearer #{auth_token}" }
        expect(::Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(headers: hash_including(headers)))
          .and_call_original

        make_request
      end

      it 'includes basic auth even when JWT is enabled' do
        expect(::Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(basic_auth: instance_of(Hash)))
          .and_call_original

        make_request
      end
    end
  end

  shared_examples 'with relative base_url' do |method|
    let(:base_url) { [zoekt_node.index_base_url, 'nodes', 'zoekt-2'].join('/') }
    let(:custom_node) { create(:zoekt_node, index_base_url: base_url, search_base_url: base_url) }
    let(:body) { {} }
    let(:response) { instance_double(Net::HTTPResponse, body: body.to_json) }
    let(:success) do
      instance_double(HTTParty::Response,
        code: 200, success?: true, parsed_response: body, response: response, body: response.body
      )
    end

    it 'send request to the correct URL' do
      raise 'Unknown method' if %i[delete post].exclude?(method)

      requested_url = custom_node.index_base_url + expected_path
      expect(Gitlab::HTTP).to receive(method).with(requested_url, anything).and_return(success)
      make_request
    end
  end

  shared_examples 'with connection errors' do |method|
    Gitlab::HTTP::HTTP_ERRORS.each do |error|
      context "when an `#{error}` is raised while trying to connect to zoekt" do
        before do
          allow(::Gitlab::HTTP).to receive(method).and_raise(error)
        end

        it { expect { subject }.to raise_error(::Search::Zoekt::Errors::ClientConnectionError) }
      end
    end

    context 'when an exception is raised during json parsing' do
      let(:invalid_json_body) { '' }
      let(:response) { instance_double(HTTParty::Response, code: 200, success?: true, body: invalid_json_body) }

      before do
        allow(::Gitlab::HTTP).to receive(method).and_return response
      end

      it { expect { subject }.to raise_error(::Search::Zoekt::Errors::ClientConnectionError) }
    end
  end

  describe '#search' do
    let(:project_ids) { [project_1.id, project_2.id] }
    let(:query) { 'use.*egex' }
    let(:node) { ::Search::Zoekt::Node.last }
    let(:node_id) { node.id }
    let(:search_mode) { 'regex' }

    subject(:search) do
      client.search(query, num: 10, project_ids: project_ids, node_id: node_id, search_mode: search_mode)
    end

    it 'returns the matching files from all searched projects' do
      expect(search.result[:Files].pluck(:FileName)).to include(
        "files/ruby/regex.rb", "files/markdown/ruby-style-guide.md"
      )

      expect(search.result[:Files].map { |r| r[:RepositoryID].to_i }.uniq).to contain_exactly(
        project_1.id, project_2.id
      )
    end

    context 'when there is no project_id filter' do
      let(:project_ids) { [] }

      it 'raises an error if there are somehow no project_id in the filter' do
        expect { search }.to raise_error('Not possible to search without at least one project specified')
      end
    end

    context 'when project_id filter is any' do
      let(:project_ids) { :any }

      it 'raises an error if somehow :any is sent as project_ids' do
        expect { search }.to raise_error('Global search is not supported')
      end
    end

    context 'when search_mode is regex' do
      let(:query) { 'lots code do a' }

      it 'performs regex search and result is not empty' do
        expect(search.result[:Files]).not_to be_nil
      end
    end

    context 'when search_mode is exact' do
      let(:query) { 'lots code do a' }
      let(:search_mode) { 'exact' }

      it 'performs exact search and result is empty' do
        expect(search.result[:Files]).to be_nil
      end
    end

    context 'when search_mode is neither exact nor regex' do
      let(:search_mode) { 'dummy' }

      it 'raises an error' do
        expect { search }.to raise_error(ArgumentError, 'Not a valid search_mode')
      end
    end

    context 'when search_mode is not passed' do
      it 'raises an error' do
        expect { client.search(query, num: 10, project_ids: project_ids, node_id: node_id) }.to raise_error(
          ArgumentError, 'missing keyword: :search_mode')
      end
    end

    context 'with an invalid search' do
      let(:query) { '(invalid search(' }

      it 'logs an error and returns an empty array for results', :aggregate_failures do
        logger = instance_double(::Search::Zoekt::Logger)
        expect(::Search::Zoekt::Logger).to receive(:build).and_return(logger)
        expect(logger).to receive(:error).with(hash_including('status' => 400))

        expect(search.error_message).to include('error parsing regexp')
      end
    end

    it_behaves_like 'an authenticated zoekt request' do
      let(:make_request) { search }
    end

    it_behaves_like 'with relative base_url', :post do
      let(:make_request) { search }
      let(:expected_path) { '/api/search' }
    end

    it_behaves_like 'with connection errors', :post

    context 'when ZOEKT_CLIENT_DEBUG env var is true' do
      before do
        stub_env('ZOEKT_CLIENT_DEBUG', true)
      end

      it 'logs the request and response' do
        logger = instance_double(::Search::Zoekt::Logger)
        expect(::Search::Zoekt::Logger).to receive(:build).and_return(logger)
        expect(logger).to receive(:debug)
          .with(hash_including('message' => 'Zoekt HTTP post request', 'url' => anything, 'payload' => anything))
        expect(logger).to receive(:debug).with(hash_including('message' => 'Zoekt HTTP response', 'data' => anything))

        search
      end

      it 'only logs for dev or test environments' do
        allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)
        expect(::Search::Zoekt::Logger).not_to receive(:build)

        search
      end
    end
  end

  describe '#search_zoekt_proxy' do
    let(:project_ids) { [project_1.id, project_2.id] }
    let(:query) { 'use.*egex' }
    let(:node) { ::Search::Zoekt::Node.last }
    let(:node_id) { node.id }
    let(:search_mode) { 'regex' }
    let(:targets) { { node_id => project_ids } }

    subject(:search) do
      client.search_zoekt_proxy(query, num: 10, targets: targets, search_mode: search_mode)
    end

    it_behaves_like 'an authenticated zoekt request' do
      let(:make_request) { search }
    end

    it_behaves_like 'with relative base_url', :post do
      let(:make_request) { search }
      let(:expected_path) { '/webserver/api/v2/search' }
    end

    context 'when zoekt_ast_search_payload feature flag is disabled' do
      before do
        stub_feature_flags(zoekt_ast_search_payload: false)
      end

      it_behaves_like 'an authenticated zoekt request' do
        let(:make_request) { search }
      end

      it_behaves_like 'with relative base_url', :post do
        let(:make_request) { search }
        let(:expected_path) { '/webserver/api/v2/search' }
      end
    end
  end
end
