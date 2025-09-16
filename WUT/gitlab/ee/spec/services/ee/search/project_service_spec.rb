# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ProjectService, feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:group) { create(:group) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  context 'when a single project provided' do
    it_behaves_like 'EE search service shared examples', ::Gitlab::ProjectSearchResults,
      ::Gitlab::Elastic::ProjectSearchResults do
      let_it_be(:scope) { create(:project) }

      let(:user) { scope.first_owner }
      let(:service) { described_class.new(user, scope, params) }
    end
  end

  describe '#search_type' do
    let(:search_service) { described_class.new(user, project, scope: scope) }

    subject(:search_type) { search_service.search_type }

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

      context 'when use_default_branch? is false' do
        before do
          allow(search_service).to receive(:use_default_branch?).and_return(false)
        end

        it { is_expected.to eq('basic') }
      end

      %w[basic advanced zoekt].each do |search_type|
        context "with search_type param #{search_type}" do
          let(:search_service) do
            described_class.new(user, project, { scope: scope, search_type: search_type })
          end

          it { is_expected.to eq(search_type) }
        end
      end
    end
  end

  describe '#elasticsearchable_scope' do
    let(:service) { described_class.new(user, project, scope: scope) }
    let(:scope) { 'blobs' }

    it 'is set to project' do
      expect(service.elasticsearchable_scope).to eq(project)
    end

    context 'when the scope is users' do
      let(:scope) { 'users' }

      it 'is nil' do
        expect(service.elasticsearchable_scope).to be_nil
      end
    end
  end

  context 'when searching with Zoekt', :zoekt_settings_enabled do
    let_it_be_with_reload(:project) { create(:project, :public) }

    let(:service) do
      described_class.new(
        (anonymous_user ? nil : user),
        project,
        search: 'foobar',
        scope: scope,
        advanced_search: advanced_search,
        source: source
      )
    end

    let_it_be(:zoekt_nodes_list) { create_list(:zoekt_node, 2) }
    let(:zoekt_nodes) { Search::Zoekt::Node.id_in(zoekt_nodes_list) }
    let(:search_code_with_zoekt) { true }
    let(:user_preference_enabled_zoekt) { true }
    let(:scope) { 'blobs' }
    let(:advanced_search) { nil }
    let(:anonymous_user) { false }
    let(:source) { nil }

    before do
      allow(project).to receive(:search_code_with_zoekt?).and_return(search_code_with_zoekt)
      allow(user).to receive(:enabled_zoekt?).and_return(user_preference_enabled_zoekt)
      zoekt_ensure_namespace_indexed!(project.root_namespace)

      allow(service).to receive(:zoekt_nodes).and_return zoekt_nodes
    end

    it 'searches with Zoekt' do
      expect(service.use_zoekt?).to be(true)
      expect(service.search_type).to eq('zoekt')
      expect(service.zoekt_searchable_scope).to eq(project)
      expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
    end

    context 'when advanced search is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
      end

      it 'returns a Search::Zoekt::SearchResults' do
        expect(service.use_zoekt?).to be(true)
        expect(service.zoekt_searchable_scope).to eq(project)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when project does not have Zoekt enabled' do
      let(:search_code_with_zoekt) { false }

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when project is archived' do
      it 'sets include_archived and exclude_forks filters to false' do
        project.update!(archived: true)

        expect(service.use_zoekt?).to be(true)
        expect(service.zoekt_searchable_scope).to eq(project)
        result = service.execute
        expect(result).to be_kind_of(::Search::Zoekt::SearchResults)
        expect(result.filters[:include_archived]).to be(true)
        expect(result.filters[:exclude_forks]).to be(false)
      end
    end

    context 'when scope is not blobs' do
      let(:scope) { 'issues' }

      it 'does not search with Zoekt' do
        expect(service.search_type).not_to eq('zoekt')
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when basic search is requested' do
      let(:service) do
        described_class.new(
          (anonymous_user ? nil : user),
          project,
          search: 'foobar',
          scope: scope,
          advanced_search: advanced_search,
          search_type: 'basic',
          source: source
        )
      end

      it 'does not search with Zoekt' do
        expect(service.search_type).to eq('basic')
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when user set enabled_zoekt preference to false' do
      let(:user_preference_enabled_zoekt) { false }

      it 'does not search with Zoekt' do
        expect(service).not_to be_use_zoekt
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when anonymous user' do
      let(:anonymous_user) { true }

      it 'searches with Zoekt' do
        expect(service.use_zoekt?).to be(true)
        expect(service.zoekt_searchable_scope).to eq(project)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when search comes from API' do
      let(:source) { 'api' }

      it 'searches with Zoekt' do
        expect(service.use_zoekt?).to be(true)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end

      context 'when zoekt_search_api is disabled' do
        before do
          stub_feature_flags(zoekt_search_api: false)
        end

        it 'does not search with Zoekt' do
          expect(service.use_zoekt?).to be(false)
          expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
        end

        context 'when search_type is zoekt' do
          let(:service) do
            described_class.new(
              (anonymous_user ? nil : user),
              project,
              search: 'foobar',
              scope: scope,
              advanced_search: advanced_search,
              source: source,
              search_type: 'zoekt'
            )
          end

          it 'searches with Zoekt' do
            expect(service.use_zoekt?).to be(true)
            expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
          end
        end
      end
    end

    context 'when feature flag disable_zoekt_search_for_saas is enabled' do
      before do
        stub_feature_flags(disable_zoekt_search_for_saas: true)
      end

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end
  end

  context 'with default branch support' do
    let_it_be(:scope) { create(:project) }

    let(:user) { scope.owner }
    let(:service) { described_class.new(user, scope, params) }

    describe '#use_default_branch?' do
      subject { service.use_default_branch? }

      context 'when repository_ref param is blank' do
        let(:params) { { search: '*' } }

        it { is_expected.to be_truthy }
      end

      context 'when repository_ref param provided' do
        let(:params) { { search: '*', scope: search_scope, repository_ref: 'test' } }

        where(:search_scope, :default_branch_given, :use_default_branch) do
          'issues'          | true   | true
          'issues'          | false  | true
          'merge_requests'  | true   | true
          'merge_requests'  | false  | true
          'notes'           | true   | true
          'notes'           | false  | true
          'milestones'      | true   | true
          'milestones'      | false  | true
          'blobs'           | true   | true
          'blobs'           | false  | false
          'wiki_blobs'      | true   | true
          'wiki_blobs'      | false  | false
          'commits'         | true   | true
          'commits'         | false  | false
        end

        with_them do
          before do
            allow(scope).to receive(:root_ref?).and_return(default_branch_given)
          end

          it { is_expected.to eq(use_default_branch) }
        end
      end
    end

    describe '#execute' do
      let(:params) { { search: '*' } }

      subject { service.execute }

      it 'returns Elastic results when searching non-default branch' do
        expect(service).to receive(:use_default_branch?).and_return(true)

        is_expected.to be_a(::Gitlab::Elastic::ProjectSearchResults)
      end

      it 'returns ordinary results when searching non-default branch' do
        expect(service).to receive(:use_default_branch?).and_return(false)

        is_expected.to be_a(::Gitlab::ProjectSearchResults)
      end
    end
  end

  context 'for sorting', :elastic_delete_by_query do
    context 'with issues' do
      let(:scope) { 'issues' }

      let!(:old_result) { create(:work_item, project: project, title: 'sorted old', created_at: 1.month.ago) }
      let!(:new_result) { create(:work_item, project: project, title: 'sorted recent', created_at: 1.day.ago) }
      let!(:very_old_result) { create(:work_item, project: project, title: 'sorted very old', created_at: 1.year.ago) }

      let!(:old_updated) { create(:work_item, project: project, title: 'updated old', updated_at: 1.month.ago) }
      let!(:new_updated) { create(:work_item, project: project, title: 'updated recent', updated_at: 1.day.ago) }
      let!(:very_old_updated) do
        create(:work_item, project: project, title: 'updated very old', updated_at: 1.year.ago)
      end

      before do
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, project, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, project, search: 'updated', sort: sort).execute }
      end
    end

    context 'with merge requests' do
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

      before do
        Elastic::ProcessInitialBookkeepingService.track!(old_result, new_result, very_old_result, old_updated,
          new_updated, very_old_updated)
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, project, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, project, search: 'updated', sort: sort).execute }
      end
    end
  end

  describe '#scope' do
    subject(:service) { described_class.new(user, project, scope: scope) }

    context 'when scope passed is included in allowed_scopes' do
      let(:scope) { 'issues' }

      it 'returns that scope' do
        expect(service.scope).to eq('issues')
      end

      context 'when user does not have permission for the scope' do
        it 'chooses the first allowed scope which the user has permission for' do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_issue, project).and_return(false)
          allow(Ability).to receive(:allowed?).with(user, :read_code, project).and_return(false)

          expect(service.scope).to eq('merge_requests')
        end
      end
    end

    context 'when scope passed is not included in allowed_scopes' do
      let(:scope) { 'epics' }

      it 'chooses the first allowed scope which the user has permission for' do
        expect(service.scope).to eq('blobs')
      end
    end
  end

  describe '#zoekt_nodes' do
    subject(:service) { described_class.new(user, project, scope: 'blobs') }

    it 'calls on Node.searchable_for_project' do
      expect(Search::Zoekt::Node).to receive(:searchable_for_project).with(project).and_return(:result)
      expect(service.zoekt_nodes).to eq(:result)
    end
  end

  describe '#search_level' do
    it 'returns project' do
      expect(described_class.new(user, project, scope: 'notes').search_level).to eq :project
    end
  end

  describe 'issues search', :elastic_delete_by_query do
    let(:source) { nil }
    let_it_be(:issue) { create(:issue, project: project, title: 'Hello world, here I am!') }
    let_it_be(:note) { create(:note_on_issue, note: 'Goodbye moon', noteable: issue, project: issue.project) }

    let(:service) { described_class.new(user, project, search: 'Goodbye', source: source).execute }

    before do
      Elastic::ProcessInitialBookkeepingService.track!(issue, note)
      ensure_elasticsearch_index!
    end

    subject(:issues) { service.objects('issues') }

    it 'return the issue when searching with note text' do
      expect(issues).to contain_exactly(issue)
      expect(service.issues_count).to eq 1
    end

    context 'when search_work_item_queries_notes is false' do
      before do
        stub_feature_flags(search_work_item_queries_notes: false)
      end

      it 'does not return the issue when searching with note text' do
        expect(issues).to be_empty
        expect(service.issues_count).to eq 0
      end
    end

    context 'when query source is GLQL' do
      let(:source) { 'glql' }

      it 'does not return the issue when searching with note text' do
        expect(issues).to be_empty
        expect(service.issues_count).to eq 0
      end
    end
  end
end
