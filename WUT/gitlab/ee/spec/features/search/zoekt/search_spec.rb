# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Zoekt search', :js, :disable_rate_limiter, :zoekt_settings_enabled, feature_category: :global_search do
  include ListboxHelpers

  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project1) { create(:project, :repository, :public, namespace: group) }
  let_it_be(:project2) { create(:project, :repository, :public, namespace: group) }
  let_it_be(:group2) { create(:group, :public) }
  let_it_be(:project3) { create(:project, :repository, :private, namespace: group2) }
  let_it_be(:user) { create(:user) }

  before_all do
    group.add_owner(user)
    group2.add_owner(user)
  end

  before do
    zoekt_ensure_project_indexed!(project1)
    zoekt_ensure_project_indexed!(project2)
    zoekt_ensure_project_indexed!(project3)

    sign_in(user)
    visit(search_path)
    wait_for_requests
    choose_group(group)
    select_search_scope(_('Code'))
    wait_for_all_requests
  end

  after do
    zoekt_truncate_index!
  end

  shared_examples 'zoekt search results' do |result_count|
    it 'displays the expected search results with the correct UI elements' do
      expect(page).to have_selector('.file-content .blob-content', count: result_count, wait: 60)
      expect(page).to have_link(_('Exact code search (powered by Zoekt)'),
        href: help_page_path('user/search/exact_code_search.md'))
      expect(page).to have_button(_('Copy file path'))
    end
  end

  context 'with exact search' do
    before do
      submit_search('\A[a-zA-Z0-9_\-\. ]*\z')
    end

    include_examples 'zoekt search results', 2

    context 'when filtering by project' do
      before do
        choose_project(project1)
      end

      include_examples 'zoekt search results', 1
    end
  end

  context 'with regex search' do
    before do
      find_by_testid('reqular-expression-toggle').click
      submit_search('user.*egex')
    end

    include_examples 'zoekt search results', 2

    context 'when filtering by project' do
      before do
        choose_project(project1)
      end

      include_examples 'zoekt search results', 1
    end
  end

  context 'when the user does not have the ability to read blob' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(anything, :read_blob, anything).and_return(false)
    end

    it 'does not show any search result' do
      submit_search('username_regex')

      expect(page).not_to have_selector('.file-content .blob-content')
    end
  end

  def choose_group(group)
    find_by_testid('group-filter').click
    wait_for_requests
    within_testid('group-filter') do
      select_listbox_item group.name
    end
  end

  def choose_project(project)
    find_by_testid('project-filter').click
    wait_for_requests
    within_testid('project-filter') do
      select_listbox_item project.name
    end
  end
end
