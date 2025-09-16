# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GlobalService, feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  let_it_be(:user) { create(:user) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  it_behaves_like 'EE search service shared examples', ::Gitlab::SearchResults, ::Gitlab::Elastic::SearchResults do
    let(:scope) { nil }
    let(:service) { described_class.new(user, params) }
  end

  describe '#search_type' do
    let(:search_service) { described_class.new(user, scope: scope) }

    subject(:search_type) { search_service.search_type }

    using RSpec::Parameterized::TableSyntax

    where(:use_zoekt, :use_elasticsearch, :scope, :expected_type) do
      true   | true  | 'blobs'  | 'zoekt'
      false  | true  | 'blobs'  | 'advanced'
      false  | false | 'blobs'  | 'basic'
      true   | true  | 'issues' | 'advanced'
      true   | false | 'issues' | 'basic'
    end

    with_them do
      before do
        allow(search_service).to receive_messages(scope: scope, use_zoekt?: use_zoekt,
          use_elasticsearch?: use_elasticsearch)
      end

      it { is_expected.to eq(expected_type) }

      %w[basic advanced zoekt].each do |search_type|
        context "with search_type param #{search_type}" do
          let(:search_service) { described_class.new(user, { scope: scope, search_type: search_type }) }

          it { is_expected.to eq(search_type) }
        end
      end
    end
  end

  context 'for has_parent usage', :elastic do
    shared_examples 'search does not use has_parent' do |scope, index_name|
      let(:results) { described_class.new(nil, search: '*').execute.objects(scope) }
      let(:es_host) { Gitlab::CurrentSettings.elasticsearch_url.first }
      let(:search_url) { %r{#{es_host}/#{index_name}/_search} }

      it 'does not use joins to apply permissions' do
        request = a_request(:post, search_url).with do |req|
          expect(req.body).not_to include("has_parent")
        end

        results

        expect(request).to have_been_made
      end
    end

    it_behaves_like 'search does not use has_parent', 'merge_requests', MergeRequest.index_name
    it_behaves_like 'search does not use has_parent', 'issues', ::Search::Elastic::References::WorkItem.index
    it_behaves_like 'search does not use has_parent', 'notes', Note.index_name
  end

  context 'when projects search has an empty search term', :elastic do
    subject { service.execute.objects('projects') }

    let(:service) { described_class.new(nil, search: nil) }

    it 'does not raise exception' do
      is_expected.to be_empty
    end
  end

  context 'for sorting', :elastic do
    let_it_be_with_reload(:project) { create(:project, :public) }

    before do
      Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
      ensure_elasticsearch_index!
    end

    context 'on issue' do
      let(:scope) { 'issues' }

      let_it_be(:old_result) { create(:issue, project: project, title: 'sorted old', created_at: 1.month.ago) }
      let_it_be(:new_result) { create(:issue, project: project, title: 'sorted recent', created_at: 1.day.ago) }
      let_it_be(:very_old_result) do
        create(:issue, project: project, title: 'sorted very old', created_at: 1.year.ago)
      end

      let_it_be(:old_updated) { create(:issue, project: project, title: 'updated old', updated_at: 1.month.ago) }
      let_it_be(:new_updated) { create(:issue, project: project, title: 'updated recent', updated_at: 1.day.ago) }
      let_it_be(:very_old_updated) do
        create(:issue, project: project, title: 'updated very old', updated_at: 1.year.ago)
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, search: 'updated', sort: sort).execute }
      end
    end

    context 'on merge request' do
      let(:scope) { 'merge_requests' }

      let_it_be(:old_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'old-1', title: 'sorted old',
          created_at: 1.month.ago)
      end

      let_it_be(:new_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'new-1', title: 'sorted recent',
          created_at: 1.day.ago)
      end

      let_it_be(:very_old_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'very-old-1', title: 'sorted very old',
          created_at: 1.year.ago)
      end

      let_it_be(:old_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-old-1', title: 'updated old',
          updated_at: 1.month.ago)
      end

      let_it_be(:new_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-new-1',
          title: 'updated recent', updated_at: 1.day.ago)
      end

      let_it_be(:very_old_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-very-old-1',
          title: 'updated very old', updated_at: 1.year.ago)
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, search: 'updated', sort: sort).execute }
      end
    end
  end

  describe '#allowed_scopes' do
    context 'when ES is used' do
      it 'includes ES-specific scopes' do
        expect(described_class.new(user, {}).allowed_scopes).to include('commits')
      end
    end

    context 'when elasticearch_search is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false)
      end

      it 'does not include ES-specific scopes' do
        expect(described_class.new(user, {}).allowed_scopes).not_to include('commits')
      end
    end

    context 'when elasticsearch_limit_indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      context 'when global_search_limited_indexing_enabled admin setting is disabled' do
        before do
          stub_application_setting(global_search_limited_indexing_enabled: false)
        end

        it 'does not include ES-specific scopes' do
          expect(described_class.new(user, {}).allowed_scopes).not_to include('commits')
        end
      end

      context 'when global_search_limited_indexing_enabled admin setting is enabled' do
        before do
          stub_application_setting(global_search_limited_indexing_enabled: true)
        end

        it 'includes ES-specific scopes' do
          expect(described_class.new(user, {}).allowed_scopes).to include('commits')
        end
      end
    end

    context 'for blobs scope' do
      context 'when elasticearch_search is disabled and zoekt is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: false)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(false)
        end

        it 'does not include blobs scope' do
          expect(described_class.new(user, {}).allowed_scopes).not_to include('blobs')
        end
      end

      context 'when elasticsearch_search is enabled and zoekt is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: true)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(false)
        end

        it 'includes blobs scope' do
          expect(described_class.new(user, {}).allowed_scopes).to include('blobs')
        end
      end

      context 'when elasticsearch_search is disabled and zoekt is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: false)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(true)
        end

        it 'includes blobs scope' do
          expect(described_class.new(user, {}).allowed_scopes).to include('blobs')
        end
      end
    end
  end

  describe '#elastic_projects' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:another_project) { create(:project) }
    let_it_be(:non_admin_user) { create_user_from_membership(project, :developer) }
    let_it_be(:admin) { create(:admin) }

    let(:service) { described_class.new(user, {}) }
    let(:elastic_projects) { service.elastic_projects }

    context 'when the user is an admin' do
      let(:user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it 'returns :any' do
          expect(elastic_projects).to eq(:any)
        end
      end

      context 'when admin mode is disabled' do
        it 'returns empty array' do
          expect(elastic_projects).to eq([])
        end
      end
    end

    context 'when the user is not an admin' do
      let(:user) { non_admin_user }

      it 'returns the projects the user has access to' do
        expect(elastic_projects).to eq([project.id])
      end
    end

    context 'when there is no user' do
      let(:user) { nil }

      it 'returns empty array' do
        expect(elastic_projects).to eq([])
      end
    end
  end

  context 'on confidential notes' do
    let_it_be(:project) { create(:project, :public, :repository) }

    context 'with notes on issues' do
      let_it_be(:noteable) { create(:issue, project: project) }

      it_behaves_like 'search confidential notes shared examples', :note_on_issue
    end
  end

  describe '#search_level' do
    it 'returns global' do
      expect(described_class.new(user, {}).search_level).to eq :global
    end
  end
end
