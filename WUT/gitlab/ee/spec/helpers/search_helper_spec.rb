# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchHelper, feature_category: :global_search do
  include Devise::Test::ControllerHelpers

  describe '#search_filter_input_options' do
    let(:options) { helper.search_filter_input_options(:issues) }

    context 'with multiple issue assignees feature' do
      before do
        stub_licensed_features(multiple_issue_assignees: true)
      end

      it 'allows multiple assignees in project context' do
        @project = build_stubbed(:project)

        expect(options[:data][:'multiple-assignees']).to eq('true')
      end

      it 'allows multiple assignees in group context' do
        @group = build_stubbed(:group)

        expect(options[:data][:'multiple-assignees']).to eq('true')
      end

      it 'allows multiple assignees in dashboard context' do
        expect(options[:data][:'multiple-assignees']).to eq('true')
      end
    end

    context 'without multiple issue assignees feature' do
      before do
        stub_licensed_features(multiple_issue_assignees: false)
      end

      it 'does not allow multiple assignees in project context' do
        @project = build_stubbed(:project)

        expect(options[:data][:'multiple-assignees']).to be_nil
      end

      it 'does not allow multiple assignees in group context' do
        @group = build_stubbed(:group)

        expect(options[:data][:'multiple-assignees']).to be_nil
      end

      it 'allows multiple assignees in dashboard context' do
        expect(options[:data][:'multiple-assignees']).to eq('true')
      end
    end

    describe 'epics-endpoint' do
      let_it_be(:group, refind: true) { create(:group) }
      let_it_be(:project_under_group, refind: true) { create(:project, group: group) }

      it 'includes epics endpoint in project context' do
        @project = project_under_group

        expect(options[:data]['epics-endpoint']).to eq(expose_path(api_v4_groups_epics_path(id: group.id)))
      end

      it 'includes epics endpoint in group context' do
        @group = group

        expect(options[:data]['epics-endpoint']).to eq(expose_path(api_v4_groups_epics_path(id: @group.id)))
      end

      it 'does not include epics endpoint for projects under a namespace' do
        @project = create(:project, namespace: create(:namespace))

        expect(options[:data]['epics-endpoint']).to be_nil
      end

      it 'does not include epics endpoint in dashboard context' do
        expect(options[:data]['epics-endpoint']).to be_nil
      end
    end

    describe 'iterations-endpoint' do
      let_it_be(:group, refind: true) { create(:group) }
      let_it_be(:project_under_group, refind: true) { create(:project, group: group) }

      context 'when iterations are available' do
        before do
          stub_licensed_features(iterations: true)
        end

        it 'includes iteration endpoint in project context' do
          @project = project_under_group

          expect(options[:data]['iterations-endpoint'])
            .to eq(expose_path(api_v4_projects_iterations_path(id: @project.id)))
        end

        it 'includes iteration endpoint in group context' do
          @group = group

          expect(options[:data]['iterations-endpoint']).to eq(expose_path(api_v4_groups_iterations_path(id: @group.id)))
        end

        it 'does not include iterations endpoint for projects under a namespace' do
          @project = create(:project, namespace: create(:namespace))

          expect(options[:data]['iterations-endpoint']).to be_nil
        end

        it 'does not include iterations endpoint in dashboard context' do
          expect(options[:data]['iterations-endpoint']).to be_nil
        end
      end

      context 'when iterations are not available' do
        before do
          stub_licensed_features(iterations: false)
        end

        it 'does not include iterations endpoint in project context' do
          @project = project_under_group

          expect(options[:data]['iterations-endpoint']).to be_nil
        end

        it 'does not include iterations endpoint in group context' do
          @group = group

          expect(options[:data]['iterations-endpoint']).to be_nil
        end
      end
    end
  end

  describe 'search_autocomplete_opts' do
    context "with a user" do
      let(:search_term) { 'the search term' }
      let_it_be(:user) { create(:user) }

      before do
        allow(self).to receive(:current_user).and_return(user)
      end

      it 'includes the users recently viewed epics', :aggregate_failures do
        recent_epics = instance_double(::Gitlab::Search::RecentEpics)
        expect(::Gitlab::Search::RecentEpics).to receive(:new).with(user: user).and_return(recent_epics)
        group1 = create(:group, :public, :with_avatar)
        group2 = create(:group, :public)
        epic1 = create(:epic, title: 'epic 1', group: group1)
        epic2 = create(:epic, title: 'epic 2', group: group2)

        expect(recent_epics).to receive(:search).with(search_term).and_return(Epic.id_in_ordered([epic1.id, epic2.id]))

        results = search_autocomplete_opts(search_term)

        expect(results.count).to eq(2)

        expect(results[0]).to include({
          category: 'Recent epics',
          id: epic1.id,
          label: 'epic 1',
          url: Gitlab::Routing.url_helpers.group_epic_path(epic1.group, epic1),
          avatar_url: group1.avatar_url
        })

        expect(results[1]).to include({
          category: 'Recent epics',
          id: epic2.id,
          label: 'epic 2',
          url: Gitlab::Routing.url_helpers.group_epic_path(epic2.group, epic2),
          avatar_url: '' # This group didn't have an avatar so set this to ''
        })
      end

      it 'does not have an N+1 for recently viewed epics', :aggregate_failures do
        recent_epics = instance_double(::Gitlab::Search::RecentEpics)
        allow(::Gitlab::Search::RecentEpics).to receive(:new).with(user: user).and_return(recent_epics)

        group1 = create(:group, :public, :with_avatar)
        group2 = create(:group, :public)
        epic1 = create(:epic, title: 'epic 1', group: group1)
        epic2 = create(:epic, title: 'epic 2', group: group2)
        epic_ids = [epic1.id, epic2.id]
        expect(recent_epics).to receive(:search).with(search_term).and_return(Epic.id_in_ordered(epic_ids))

        control = ActiveRecord::QueryRecorder.new(skip_cached: true) do
          search_autocomplete_opts(search_term)
        end

        epic_ids += create_list(:epic, 3).map(&:id)
        expect(recent_epics).to receive(:search).with(search_term).and_return(Epic.id_in_ordered(epic_ids))

        # avatar calls group owner but only calls it once, so use exceed_all_query_limit
        expect { search_autocomplete_opts(search_term) }.not_to exceed_all_query_limit(control)
      end

      context 'with the filter parameter is present' do
        it 'filter is set to search' do
          project = create(:project, title: 'hello world')
          project.add_developer(user)

          results = search_autocomplete_opts('hello', filter: 'search')
          expect(results.count).to eq(1)

          expect(results.first).to include({
            category: 'Projects',
            id: project.id,
            label: project.full_name,
            url: Gitlab::Routing.url_helpers.project_path(project)
          })
        end

        it 'filter is set to generic' do
          results = search_autocomplete_opts('setting', filter: 'generic')
          expect(results.count).to eq(1)

          expect(results.first).to include({
            category: 'Settings',
            label: 'User settings',
            url: Gitlab::Routing.url_helpers.user_settings_profile_path
          })
        end
      end
    end
  end

  describe '#search_entries_info_template' do
    let(:com_value) { true }
    let(:elasticsearch_enabled) { true }
    let(:show_snippets) { true }
    let(:collection) { Kaminari.paginate_array([:foo]).page(1).per(10) }
    let(:user) { build_stubbed(:user) }
    let(:message) { "Showing %{count} %{scope} for %{term_element}" }
    let(:new_message) { "#{message} in your personal and project snippets" }
    let(:count) { 1 }
    let(:scope) { 'test' }
    let(:term_element) { 'foo' }

    subject(:search) { search_entries_info_template(collection) }

    before do
      @current_user = user

      allow(self).to receive(:current_user).and_return(user)
      allow(search_service).to receive(:show_snippets?).and_return(show_snippets)
      allow(Gitlab).to receive(:com?).and_return(com_value)
      stub_ee_application_setting(search_using_elasticsearch: elasticsearch_enabled)
    end

    shared_examples 'returns old message' do
      it 'returns the message' do
        expect(search).to eq message
      end
    end

    context 'when all requirements are met' do
      it 'returns a custom message' do
        expect(search).to eq "Showing 1 test for foo in your personal and project snippets"
      end
    end

    context 'when not in Gitlab.com' do
      let(:com_value) { false }

      it_behaves_like 'returns old message'
    end

    context 'when elastic search is not enabled' do
      let(:elasticsearch_enabled) { false }

      it_behaves_like 'returns old message'
    end

    context 'when no user is present' do
      let(:user) { nil }

      it_behaves_like 'returns old message'
    end

    context 'when not searching for snippets' do
      let(:show_snippets) { nil }

      it_behaves_like 'returns old message'
    end
  end

  describe '#highlight_and_truncate_issuable' do
    let(:description) { 'hello world' }
    let(:issue) { build_stubbed(:issue, description: description) }
    let(:search_highlight) { {} }
    let_it_be(:user) { build_stubbed(:user) }

    subject(:highlight_and_truncate) { highlight_and_truncate_issuable(issue, 'test', search_highlight) }

    before do
      allow(self).to receive(:current_user).and_return(user)
      stub_ee_application_setting(search_using_elasticsearch: true)
    end

    context 'when description is not present' do
      let(:description) { nil }

      it 'does nothing' do
        expect(self).not_to receive(:sanitize)

        highlight_and_truncate
      end
    end

    context 'when description present' do
      using RSpec::Parameterized::TableSyntax

      let(:issue_id) { issue.id }

      # rubocop:disable Layout/LineLength -- table formatting
      where(:description, :search_highlight, :expected) do
        'test' | { ref(:issue_id) => { description: ['gitlabelasticsearch→test←gitlabelasticsearch'] } } | "<mark>test</mark>"
        '<span style="color: blue;">this test should not be blue</span>' | { ref(:issue_id) => { description: ['<span style="color: blue;">this gitlabelasticsearch→test←gitlabelasticsearch should not be blue</span>'] } } | "this <mark>test</mark> should not be blue"
        '<a href="#" onclick="alert(\'XSS\')">Click Me test</a>' | { ref(:issue_id) => { description: ['<a href="#" onclick="alert(\'XSS\')">Click Me gitlabelasticsearch→test←gitlabelasticsearch</a>'] } } | "<a href='#'>Click Me <mark>test</mark></a>"
        '<script type="text/javascript">alert(\'Another XSS\');</script> test' | { ref(:issue_id) => { description: ['<script type="text/javascript">alert(\'Another XSS\');</script> gitlabelasticsearch→test←gitlabelasticsearch'] } } | "alert(&apos;Another XSS&apos;); <mark>test</mark>"
        'Lorem test ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis, ultricies nec, pellentesque eu, pretium quis, sem. Nulla consequat massa quis enim. Donec.' | { ref(:issue_id) => { description: ['Lorem gitlabelasticsearch→test←gitlabelasticsearch ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis, ultricies nec, pellentesque eu, pretium quis, sem. Nulla consequat massa quis enim. Donec.'] } } | "Lorem <mark>test</mark> ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Don..."
        '<img src="https://random.foo.com/test.png" width="128" height="128" />some image' | { ref(:issue_id) => { description: ['<img src="https://random.foo.com/gitlabelasticsearch→test←gitlabelasticsearch.png" width="128" height="128" />some image'] } } | 'some image'
        '<h2 data-sourcepos="11:1-11:26" dir="auto"><a id="user-content-additional-information" class="anchor" href="#additional-information" aria-hidden="true"></a>Additional information test:</h2><textarea data-update-url="/freepascal.org/fpc/source/-/issues/6163.json" dir="auto" data-testid="textarea" class="hidden js-task-list-field"></textarea>' | { ref(:issue_id) => { description: ['<h2 data-sourcepos="11:1-11:26" dir="auto"><a id="user-content-additional-information" class="anchor" href="#additional-information" aria-hidden="true"></a>Additional information gitlabelasticsearch→test←gitlabelasticsearch:</h2><textarea data-update-url="/freepascal.org/fpc/source/-/issues/6163.json" dir="auto" data-testid="textarea" class="hidden js-task-list-field"></textarea>'] } } | "<a class='anchor' href='#additional-information'></a>Additional information <mark>test</mark>:"
      end
      # rubocop:enable Layout/LineLength

      with_them do
        it 'sanitizes, truncates, and highlights the search term' do
          expect(highlight_and_truncate).to eq(expected)
        end
      end

      context 'when sanitize returns a blank string' do
        let(:search_highlight) { { issue_id => { 'description' => ['test'] } } }
        let(:blank) { '' }

        before do
          allow(self).to receive(:sanitize).and_return(blank.dup)
        end

        it 'returns blank and does not raise an error' do
          expect(self).not_to receive(:search_truncate)

          expect(highlight_and_truncate).to be_blank
        end
      end
    end
  end

  describe '#search_sort_options_json' do
    let(:user) { build_stubbed(:user) }

    mock_relevant_sort = {
      title: _('Most relevant'),
      sortable: false,
      sortParam: 'relevant'
    }

    mock_created_sort = {
      title: _('Created date'),
      sortable: true,
      sortParam: {
        asc: 'created_asc',
        desc: 'created_desc'
      }
    }

    mock_updated_sort = {
      title: _('Updated date'),
      sortable: true,
      sortParam: {
        asc: 'updated_asc',
        desc: 'updated_desc'
      }
    }

    before do
      allow(self).to receive(:current_user).and_return(user)
    end

    context 'with advanced search enabled' do
      before do
        stub_ee_application_setting(search_using_elasticsearch: true)
      end

      it 'returns the correct data' do
        expect(search_sort_options).to eq([mock_relevant_sort, mock_created_sort, mock_updated_sort])
      end
    end

    context 'with basic search enabled' do
      it 'returns the correct data' do
        expect(search_sort_options).to eq([mock_created_sort, mock_updated_sort])
      end
    end
  end

  describe '.search_navigation_json' do
    context 'when all options enabled' do
      before do
        allow(self).to receive_messages(current_user: build(:user), can?: true, project_search_tabs?: true)
        allow(search_service).to receive_messages(show_elasticsearch_tabs?: true, show_epics?: true,
          show_snippets?: true)
        @project = nil
      end

      it 'returns items in order' do
        expect(Gitlab::Json.parse(search_navigation_json).keys)
          .to eq(%w[projects blobs issues merge_requests wiki_blobs commits notes milestones users snippet_titles])
      end
    end
  end

  describe '.search_filter_link_json' do
    using RSpec::Parameterized::TableSyntax

    context 'with data' do
      # rubocop:disable Layout/LineLength -- table formatting
      where(:scope, :label, :data, :search, :active_scope, :type) do
        "projects"       | "Projects"                | { testid: 'projects-tab' } | nil                  | "projects"        | nil
        "snippet_titles" | "Snippets"                | nil                        | { snippets: "test" } | "code"            | nil
        "projects"       | "Projects"                | { testid: 'projects-tab' } | nil                  | "issue"           | "issue"
        "snippet_titles" | "Snippets"                | nil                        | { snippets: "test" } | "snippet_titles"  | nil
      end
      # rubocop:enable Layout/LineLength

      with_them do
        it 'converts correctly' do
          @timeout = false
          @scope = active_scope
          @search_results = double
          dummy_count = 1000
          allow(self).to receive(:search_path).with(any_args).and_return("link test")

          allow(@search_results).to receive(:formatted_count).with(scope).and_return(dummy_count)
          allow(self).to receive(:search_count_path).with(any_args).and_return("test count link")

          current_scope = scope == active_scope

          expected = {
            label: label,
            scope: scope,
            data: data,
            link: "link test",
            active: current_scope
          }

          expected[:count] = dummy_count if current_scope
          expected[:count_link] = "test count link" unless current_scope

          expect(search_filter_link_json(scope, label, data, search, type)).to eq(expected)
        end
      end
    end
  end

  describe '#wiki_blob_link' do
    let_it_be(:group) { build_stubbed(:group, :wiki_repo) }
    let(:wiki_blob) do
      Gitlab::Search::FoundBlob.new(path: 'test', basename: 'test', ref: 'master', data: 'foo', startline: 2,
        group: group, group_id: group.id, group_level_blob: true)
    end

    it { expect(wiki_blob_link(wiki_blob)).to eq("/groups/#{group.path}/-/wikis/#{wiki_blob.path}") }
  end

  describe '#should_show_zoekt_results?' do
    context 'with the blobs scope and zoekt search type' do
      let(:scope) { 'blobs' }
      let(:search_type) { 'zoekt' }
      let(:project) { build_stubbed(:project) }
      let(:group) { build_stubbed(:group) }

      subject(:should_show_zoekt_results?) { helper.should_show_zoekt_results?(scope, search_type) }

      before do
        allow(helper).to receive_messages(repository_ref: nil, super: false)
      end

      context 'when FF zoekt_cross_namespace_search is enabled' do
        before do
          stub_feature_flags(zoekt_cross_namespace_search: true)
        end

        context 'when project is blank' do
          it 'returns true' do
            helper.instance_variable_set(:@project, nil)

            expect(should_show_zoekt_results?).to be true
          end
        end

        context 'when project is present' do
          before do
            helper.instance_variable_set(:@project, project)
            allow(project).to receive(:default_branch).and_return('main')
          end

          context 'when repository ref matches default branch' do
            it 'returns true' do
              allow(helper).to receive(:repository_ref).with(project).and_return('main')

              expect(should_show_zoekt_results?).to be true
            end
          end
        end
      end

      context 'when FF zoekt_cross_namespace_search is disabled' do
        before do
          stub_feature_flags(zoekt_cross_namespace_search: false)
        end

        context 'when group is present' do
          it 'returns true' do
            helper.instance_variable_set(:@group, group)
            helper.instance_variable_set(:@project, nil)

            expect(should_show_zoekt_results?).to be true
          end
        end

        context 'when project is present and repository ref matches default branch' do
          it 'returns true' do
            helper.instance_variable_set(:@project, project)
            helper.instance_variable_set(:@group, nil)
            allow(project).to receive(:default_branch).and_return('main')
            allow(helper).to receive(:repository_ref).with(project).and_return('main')

            expect(should_show_zoekt_results?).to be true
          end
        end

        context 'in other cases' do
          before do
            helper.instance_variable_set(:@project, project)
            helper.instance_variable_set(:@group, nil)
            allow(project).to receive(:default_branch).and_return('main')
            allow(helper).to receive(:repository_ref).with(project).and_return('other-branch')
          end

          it 'returns false when super returns false' do
            allow(helper).to receive(:super).and_return(false)

            expect(should_show_zoekt_results?).to be false
          end
        end
      end
    end

    context 'with any other scope or search type' do
      it 'returns false for non-blobs scope' do
        expect(helper.should_show_zoekt_results?(:any_type, 'zoekt')).to be false
      end

      it 'returns false for non-zoekt search type' do
        expect(helper.should_show_zoekt_results?('blobs', :any_type)).to be false
      end
    end
  end

  describe '#blob_data_oversize_message' do
    before do
      stub_ee_application_setting(elasticsearch_indexed_file_size_limit_kb: 256)
    end

    context 'with elasticsearch enabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: true)
      end

      it 'returns the correct message with maximum file size' do
        expect(helper.blob_data_oversize_message).to eq('The file could not be ' \
          'displayed because it is empty or larger than the maximum file size indexed (256 KiB).')
      end
    end

    context 'with elasticsearch disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false)
      end

      it 'returns the correct message with maximum file size' do
        expect(helper.blob_data_oversize_message).to eq('The file could not be displayed because it is empty.')
      end
    end
  end
end
