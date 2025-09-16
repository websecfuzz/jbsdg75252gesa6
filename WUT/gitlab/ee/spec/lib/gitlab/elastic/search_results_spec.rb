# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:limit_project_ids) { [project.id] }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe '#highlight_map' do
    using RSpec::Parameterized::TableSyntax

    let(:proxy_response) do
      [{ _source: { id: 1 }, highlight: 'test <span class="gl-font-bold">highlight</span>' }]
    end

    let(:es_empty_response) { ::Search::EmptySearchResults.new }
    let(:es_client_response) { instance_double(::Search::Elastic::ResponseMapper, highlight_map: map) }
    let(:results) { described_class.new(user, query, limit_project_ids) }
    let(:map) { { 1 => 'test <span class="gl-font-bold">highlight</span>' } }

    where(:scope, :results_method, :results_response, :expected) do
      'projects'        | :projects       | ref(:proxy_response)      | ref(:map)
      'milestones'      | :milestones     | ref(:proxy_response)      | ref(:map)
      'notes'           | :notes          | ref(:proxy_response)      | ref(:map)
      'issues'          | :issues         | ref(:es_client_response)  | ref(:map)
      'issues'          | :issues         | ref(:es_empty_response)   | {}
      'merge_requests'  | :merge_requests | ref(:proxy_response)      | ref(:map)
      'blobs'       | nil | nil | {}
      'wiki_blobs'  | nil | nil | {}
      'commits'     | nil | nil | {}
      'epics'       | nil | nil | {}
      'users'       | nil | nil | {}
      'epics'       | nil | nil | {}
      'unknown'     | nil | nil | {}
    end

    with_them do
      it 'returns the expected highlight map' do
        expect(results).to receive(results_method).and_return(results_response) if results_method

        expect(results.highlight_map(scope)).to eq(expected)
      end
    end
  end

  describe '#formatted_count' do
    using RSpec::Parameterized::TableSyntax

    let(:results) { described_class.new(user, query, limit_project_ids) }

    where(:scope, :count_method, :value, :expected) do
      'projects'       | :projects_count       | 0     | '0'
      'notes'          | :notes_count          | 100   | '100'
      'blobs'          | :blobs_count          | 1000  | '1,000'
      'wiki_blobs'     | :wiki_blobs_count     | 1111  | '1,111'
      'commits'        | :commits_count        | 9999  | '9,999'
      'issues'         | :issues_count         | 10000 | '10,000+'
      'merge_requests' | :merge_requests_count | 20000 | '10,000+'
      'milestones'     | :milestones_count     | nil   | '0'
      'epics'          | :epics_count          | 200   | '200'
      'users'          | :users_count          | 100   | '100'
      'epics'          | :epics_count          | 100   | '100'
      'unknown'        | nil                   | nil   | nil
    end

    with_them do
      it 'returns the expected formatted count limited and delimited' do
        expect(results).to receive(count_method).and_return(value) if count_method
        expect(results.formatted_count(scope)).to eq(expected)
      end
    end
  end

  describe '#aggregations', :elastic_delete_by_query do
    using RSpec::Parameterized::TableSyntax

    let(:results) { described_class.new(user, query, limit_project_ids) }

    subject(:aggregations) { results.aggregations(scope) }

    where(:scope, :expected_aggregation_name, :feature_flag) do
      'projects'       | nil        | false
      'milestones'     | nil        | false
      'notes'          | nil        | false
      'issues'         | 'labels'   | false
      'merge_requests' | 'labels'   | false
      'wiki_blobs'     | nil        | false
      'commits'        | nil        | false
      'users'          | nil        | false
      'epics'          | nil        | false
      'unknown'        | nil        | false
      'blobs'          | 'language' | false
    end

    with_them do
      context 'when feature flag is enabled for user' do
        let(:feature_enabled) { true }

        before do
          stub_feature_flags(feature_flag => user) if feature_flag
          results.objects(scope) # run search to populate aggregations
        end

        it_behaves_like 'loads expected aggregations'
      end

      context 'when feature flag is disabled for user' do
        let(:feature_enabled) { false }

        before do
          stub_feature_flags(feature_flag => false) if feature_flag
          results.objects(scope) # run search to populate aggregations
        end

        it_behaves_like 'loads expected aggregations'
      end
    end
  end

  describe '#counts' do
    let(:results) { described_class.new(user, query, limit_project_ids) }

    it 'returns an empty array' do
      expect(results.counts).to be_empty
    end
  end

  describe 'parse_search_result' do
    let_it_be(:project) { create(:project) }
    let(:content) { "foo\nbar\nbaz\n" }
    let(:path) { 'path/file.ext' }
    let(:source) do
      {
        'project_id' => project.id,
        'blob' => {
          'commit_sha' => 'sha',
          'content' => content,
          'path' => path
        }
      }
    end

    it 'returns an unhighlighted blob when no highlight data is present' do
      parsed = described_class.parse_search_result({ '_source' => source }, project)

      expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
      expect(parsed).to have_attributes(
        startline: 1,
        highlight_line: nil,
        project: project,
        data: "foo\n"
      )
    end

    it 'parses the blob with highlighting' do
      result = {
        '_source' => source,
        'highlight' => {
          'blob.content' =>
            ["foo\n#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG}" \
              "bar#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG}\nbaz\n"]
        }
      }

      parsed = described_class.parse_search_result(result, project)

      expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
      expect(parsed).to have_attributes(
        id: nil,
        path: 'path/file.ext',
        basename: 'path/file',
        ref: 'sha',
        startline: 2,
        highlight_line: 2,
        project: project,
        data: "bar\n"
      )
    end

    context 'when the highlighting finds the same terms multiple times' do
      let(:content) do
        <<~CONTENT
          bar
          bar
          foo
          bar # this is the highlighted bar
          baz
          boo
          bar
        CONTENT
      end

      it 'does not mistake a line that happens to include the same term that was highlighted on a later line' do
        highlighted_content = <<~CONTENT
          bar
          bar
          foo
          #{::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG}bar#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG} # this is the highlighted bar
          baz
          boo
          bar
        CONTENT

        result = {
          '_source' => source,
          'highlight' => {
            'blob.content' => [highlighted_content]
          }
        }

        parsed = described_class.parse_search_result(result, project)

        expected_data = <<~EXPECTED_DATA
          bar
          foo
          bar # this is the highlighted bar
          baz
          boo
        EXPECTED_DATA

        expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
        expect(parsed).to have_attributes(
          id: nil,
          path: 'path/file.ext',
          basename: 'path/file',
          ref: 'sha',
          startline: 2,
          highlight_line: 4,
          project: project,
          data: expected_data
        )
      end
    end

    context 'when file path in the blob contains potential backtracking regex attack pattern' do
      let(:path) { '/group/project/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab.(a+)+$' }

      it 'still parses the basename from the path with reasonable amount of time' do
        Timeout.timeout(3.seconds) do
          parsed = described_class.parse_search_result({ '_source' => source }, project)

          expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
          expect(parsed).to have_attributes(
            basename: '/group/project/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab'
          )
        end
      end
    end

    context 'when blob is a group level result' do
      let_it_be(:group) { create(:group) }
      let_it_be(:source) do
        {
          'type' => 'wiki_blob',
          'group_id' => group.id,
          'commit_sha' => 'sha',
          'content' => 'Test',
          'path' => 'home.md'
        }
      end

      it 'returns an instance of Gitlab::Search::FoundBlob with group_level_blob as true' do
        parsed = described_class.parse_search_result({ '_source' => source }, group)

        expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
        expect(parsed).to have_attributes(group: group, project: nil, group_level_blob: true)
      end
    end
  end

  describe '#failed' do
    let(:results) { described_class.new(user, query, limit_project_ids) }
    let(:response_mapper) { instance_double(::Search::Elastic::ResponseMapper, failed?: true) }

    before do
      allow(results).to receive(:issues).and_return(response_mapper)
    end

    context 'for issues scope' do
      let(:scope) { 'issues' }

      it 'returns failed from the response mapper' do
        expect(results.failed?(scope)).to be true
      end
    end

    context 'for other scopes' do
      let(:scope) { 'blobs' }

      it 'returns false' do
        expect(results.failed?(scope)).to be false
      end
    end
  end

  describe '#error' do
    let(:results) { described_class.new(user, query, limit_project_ids) }
    let(:response_mapper) { instance_double(::Search::Elastic::ResponseMapper, error: 'An error occurred') }

    before do
      allow(results).to receive(:issues).and_return(response_mapper)
    end

    context 'for issues scope' do
      let(:scope) { 'issues' }

      it 'returns the error from the response mapper' do
        expect(results.error(scope)).to eq 'An error occurred'
      end
    end

    context 'for other scopes' do
      let(:scope) { 'blobs' }

      it 'returns nil' do
        expect(results.error(scope)).to be_nil
      end
    end
  end
end
