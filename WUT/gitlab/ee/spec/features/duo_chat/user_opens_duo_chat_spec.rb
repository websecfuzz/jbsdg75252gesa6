# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat > User opens Duo Chat', :js, :saas, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }

  before_all do
    group.add_developer(user)
  end

  before do
    allow(user).to receive(:allowed_to_use?).and_return(true)
    allow(user).to receive(:can?).and_call_original

    sign_in(user)
  end

  describe 'opening Duo Chat' do
    before do
      visit project_path(project)

      # close button for the popover
      find_by_testid('close-button').click
    end

    it 'shows the Duo Chat button' do
      expect(page).to have_selector('button.js-tanuki-bot-chat-toggle')
    end

    it 'opens Duo Chat drawer when button is clicked' do
      find('button.js-tanuki-bot-chat-toggle').click
      wait_for_requests

      expect(page).to have_css('.duo-chat-container')
    end
  end

  describe 'closing Duo Chat' do
    before do
      visit project_path(project)
      find_by_testid('close-button').click

      find('button.js-tanuki-bot-chat-toggle').click
      wait_for_requests
    end

    it 'closes Duo Chat drawer when close button is clicked' do
      find_by_testid('chat-close-button').click

      expect(page).not_to have_css('.duo-chat-container')
    end
  end

  describe 'opening Duo Chat from Action button' do
    let_it_be(:pipeline) do
      create(
        :ci_pipeline,
        project: project,
        user: user
      )
    end

    let_it_be(:build) { create(:ci_build, :trace_artifact, :failed, pipeline: pipeline) }

    before do
      stub_licensed_features(ai_features: true, troubleshoot_job: true)

      visit project_job_path(project, build)
    end

    it 'opens Duo Chat with troubleshoot prompt when Troubleshoot button is clicked' do
      find_by_testid('rca-duo-button').click
      wait_for_requests

      expect(page).to have_css('.duo-chat-container')
      expect(page).to have_content(/troubleshoot/i)
    end
  end
end
