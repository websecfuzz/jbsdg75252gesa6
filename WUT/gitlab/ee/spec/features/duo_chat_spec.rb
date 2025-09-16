# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat', :js, :saas, :clean_gitlab_redis_cache, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  before do
    group.add_developer(user)
  end

  context 'when group does not have an AI features license' do
    let_it_be_with_reload(:group) { create(:group_with_plan) }

    before do
      sign_in(user)
      visit group_path(group)
    end

    it 'does not show the button to open chat' do
      expect(page).not_to have_button('GitLab Duo Chat')
    end
  end

  context 'when group has an AI features license', :sidekiq_inline do
    using RSpec::Parameterized::TableSyntax

    include_context 'with duo features enabled and ai chat available for group on SaaS'

    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }
    let_it_be(:project) { create(:project, namespace: group) }

    let(:question) { 'Who are you?' }
    let(:answer) { "Hello! I'm GitLab Duo Chat" }
    let(:chat_response) do
      create(:final_answer_multi_chunk, chunks: ["Hello", "!", " I", "'m Git", "Lab Duo", " Chat,"])
    end

    before do
      stub_request(:post, "#{Gitlab::AiGateway.url}/v2/chat/agent")
        .with(body: hash_including({ "prompt" => question }))
        .to_return(status: 200, body: chat_response)

      sign_in(user)

      visit group_path(group)
    end

    where(:disabled_reason, :visit_path, :expected_button_state, :expected_tooltip) do
      'project' | :visit_project | :disabled | "An administrator has turned off GitLab Duo for this project"
      'project' | :visit_root | :hidden | nil
      'group' | :visit_group | :disabled | "An administrator has turned off GitLab Duo for this group"
      'group' | :visit_root | :hidden | nil
      nil | :visit_group | :enabled | nil
      nil | :visit_project | :enabled | nil
      nil | :visit_root | :hidden | nil
    end

    with_them do
      it 'shows the correct button state and tooltip' do
        allow(::Gitlab::Llm::TanukiBot).to receive(:chat_disabled_reason).and_return(disabled_reason)

        case visit_path
        when :visit_group
          visit group_path(group)
        when :visit_project
          visit project_path(project)
        when :visit_root
          visit root_path
        end

        case expected_button_state
        when :disabled
          expect(page).to have_selector(
            "span.has-tooltip[title*=\"#{expected_tooltip}\"]"
          )
          expect(page).to have_button('GitLab Duo Chat', disabled: true)
        when :enabled
          expect(page).to have_button('GitLab Duo Chat', disabled: false)
        when :hidden
          expect(page).not_to have_button('GitLab Duo Chat')
        end
      end
    end

    it 'returns response after asking a question', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/462444' do
      open_chat
      chat_request(question)

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(answer)
      end
    end

    it 'stores the chat history', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/462445' do
      open_chat
      chat_request(question)

      page.refresh
      open_chat

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(answer)
      end
    end

    it 'syncs the chat on a second tab', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/462446' do
      second_window = page.open_new_window

      within_window second_window do
        visit root_path
        open_chat
      end

      open_chat
      chat_request(question)

      within_window second_window do
        within_testid('chat-component') do
          expect(page).to have_content(question)
          expect(page).to have_content(answer)
        end
      end
    end
  end

  def open_chat
    click_button "GitLab Duo Chat"
  end

  def chat_request(question)
    fill_in 'GitLab Duo Chat', with: question
    send_keys :enter
    wait_for_requests
  end
end
