# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat > User navigates Duo Chat history', :js, :saas, :with_current_organization, feature_category: :duo_chat do
  let_it_be(:user) { create(:user, organizations: [current_organization]) }
  let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan, organization: current_organization) }
  let_it_be(:project) { create(:project, :public, group: group, organization: current_organization) }
  let_it_be(:thread) do
    create(:ai_conversation_thread, user: user, organization: current_organization).tap do |thread|
      create(:ai_conversation_message, content: 'Chat Message', role: :user, thread: thread,
        organization: current_organization)
      create(:ai_conversation_message, content: 'Response', role: :assistant, thread: thread,
        organization: current_organization)
    end
  end

  before_all do
    group.add_developer(user)
  end

  before do
    allow(user).to receive(:allowed_to_use?).and_return(true)
    allow(user).to receive(:can?).and_call_original

    sign_in(user)

    visit project_path(project)

    # Close the popover.
    find_by_testid('close-button').click

    # Open Duo Chat.
    find('button.js-tanuki-bot-chat-toggle').click
    wait_for_requests
  end

  context 'when Chat History button is clicked' do
    it 'opens chat history list' do
      find_by_testid("go-back-to-list-button").click
      wait_for_requests

      expect(page).to have_css('[data-testid="chat-threads-thread-box"]')
      expect(page).to have_content('Chat Message')
    end
  end

  context 'when existing Chat is clicked from the threads list' do
    it 'opens the chat' do
      find_by_testid('go-back-to-list-button').click
      wait_for_requests

      find_by_testid('chat-threads-thread-box').click
      wait_for_requests

      expect(page).to have_css('[data-testid="chat-subtitle"]', text: 'Chat Message')
    end
  end

  context 'when New Chat button is clicked from the threads list' do
    it 'creates a new chat' do
      find_by_testid('go-back-to-list-button').click
      wait_for_requests

      find_by_testid('chat-new-button').click
      wait_for_requests

      expect(page).to have_css('[data-testid="gl-duo-chat-empty-state"]')
    end
  end

  context 'when New Chat button is clicked from existing chat' do
    it 'creates a new chat' do
      find_by_testid('go-back-to-list-button').click
      wait_for_requests

      find_by_testid('chat-threads-thread-box').click
      wait_for_requests

      find_by_testid('chat-new-button').click
      wait_for_requests

      expect(page).to have_css('[data-testid="gl-duo-chat-empty-state"]')
    end
  end
end
