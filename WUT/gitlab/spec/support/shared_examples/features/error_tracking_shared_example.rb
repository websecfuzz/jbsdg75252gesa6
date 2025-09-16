# frozen_string_literal: true

require 'time'

RSpec.shared_examples 'error tracking index page' do
  it 'renders the error index page', quarantine: { issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/217810' } do
    within('[data-testid="breadcrumb-links"]') do
      expect(page).to have_content(project.namespace.name)
      expect(page).to have_content(project.name)
    end

    expect(page).to have_content('Open errors')
    expect(page).to have_content('Events')
    expect(page).to have_content('Users')
    expect(page).to have_content('Last seen')
  end

  it 'loads the error show page on click', quarantine: { issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/217810' } do
    click_on issues_response[0]['title']

    wait_for_requests

    expect(page).to have_content('Error Details')
  end

  it 'renders the error index data', quarantine: { issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/217810' } do
    expect(page).to have_content(issues_response[0]['title'])
    expect(page).to have_content(issues_response[0]['count'].to_s)
    expect(page).to have_content(issues_response[0]['last_seen'])
  end
end

RSpec.shared_examples 'expanded stack trace context' do |selected_line: nil, expected_line: 1|
  it 'expands the stack trace context', quarantine: { issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/217810' } do
    within('div.stacktrace') do
      find("div.file-holder:nth-child(#{selected_line}) svg[data-testid='chevron-right-icon']").click if selected_line

      expanded_line = find("div.file-holder:nth-child(#{expected_line})")
      expect(expanded_line).to have_css('svg[data-testid="chevron-down-icon"]')

      event_response['entries'][0]['data']['values'][0]['stacktrace']['frames'][-expected_line]['context'].each do |context|
        expect(page).to have_content(context[0])
      end
    end
  end
end

RSpec.shared_examples 'error tracking show page' do
  it 'renders the error details', quarantine: { issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/217810' } do
    content = page.find(".content")
    nav = find_by_testid("breadcrumb-links")
    header = page.find(".error-details-header")

    issue_response['firstRelease']['shortVersion']
    first_seen_time = page.find('div[data-testid="first-release-card"] time')['datetime']
    expected_time = issue_response["firstSeen"]

    first_year = Time.iso8601(first_seen_time).year
    expected_year = Time.iso8601(expected_time).year

    expect(header).to have_content('1 month ago by raven.scripts.runner in main')
    expect(content).to have_content(issue_response['metadata']['title'])
    expect(content).to have_content('level: error')
    expect(nav).to have_content('Error Details')
    expect(page).to have_link('View issue', href: "https://gitlab.com/gitlab-org/gitlab/issues/1")
    expect(content).to have_content("Sentry event: https://sentrytest.gitlab.com/sentry-org/sentry-project/issues/#{issue_id}")
    expect(page).to have_css('div[data-testid="first-release-card"] time', text: "1 year ago", wait: 20)
    expect(first_year).to eq(expected_year)

    within('[data-testid="error-count-card"]') do
      expect(page).to have_content("Events")
      expect(page).to have_content("1")
    end

    within('[data-testid="user-count-card"]') do
      expect(page).to have_content('Users')
      expect(page).to have_content('0')
    end
  end

  it 'renders the stack trace heading', quarantine: { issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/217810' } do
    expect(page).to have_content('Stack trace')
  end

  it 'renders the stack trace', quarantine: { issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/217810' } do
    event_response['entries'][0]['data']['values'][0]['stacktrace']['frames'].each do |frame|
      expect(frame['filename']).not_to be_nil
      expect(page).to have_selector("[data-clipboard-text='#{frame['filename']}']", visible: :all)
    end
  end

  # The first line is expanded by default if no line is selected
  it_behaves_like 'expanded stack trace context', selected_line: nil, expected_line: 1
  it_behaves_like 'expanded stack trace context', selected_line: 8, expected_line: 8
end
