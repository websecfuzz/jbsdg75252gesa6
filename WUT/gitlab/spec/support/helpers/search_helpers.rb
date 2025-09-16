# frozen_string_literal: true

module SearchHelpers
  def fill_in_search(text)
    find_by_testid('super-sidebar-search-button').click
    fill_in 'search', with: text

    wait_for_all_requests
  end

  def submit_search(query)
    if page.has_css?('.search-page-form')
      search_form = '.search-page-form'

    else
      find_by_testid('super-sidebar-search-button').click
      search_form = '#super-sidebar-search-modal'
    end

    wait_for_all_requests

    page.within(search_form) do
      field = find_field('search')
      field.click
      field.fill_in(with: query)

      if javascript_test?
        field.send_keys(:enter)
      else
        click_button('Search')
      end

      wait_for_all_requests
    end
  end

  def submit_dashboard_search(query)
    visit(search_path) unless page.has_css?('#dashboard_search')

    search_form = page.find('input[name="search"]', match: :first)

    search_form.fill_in(with: query)
    search_form.send_keys(:enter)
  end

  def select_search_scope(scope)
    within_testid('search-filter') do
      click_link scope

      wait_for_all_requests
    end
  end

  def has_search_scope?(scope)
    return false unless has_testid?('search-filter')

    within_testid('search-filter') do
      has_link?(scope)
    end
  end

  def max_limited_count
    Gitlab::SearchResults::COUNT_LIMIT_MESSAGE
  end
end
