# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dashboard todos', feature_category: :notifications do
  let_it_be(:user) { create(:user) }

  let(:page_path) { dashboard_todos_path }

  it_behaves_like 'dashboard ultimate trial callout'

  context 'User has a todo in a epic', :js do
    let_it_be(:group) { create(:group) }
    let_it_be(:target) { create(:epic, group: group) }
    let_it_be(:note) { create(:note, noteable: target, note: "#{user.to_reference} hello world") }
    let_it_be(:todo) do
      create(
        :todo, :mentioned,
        user: user,
        project: nil,
        group: group,
        target: target,
        author: user,
        note: note
      )
    end

    before do
      stub_licensed_features(epics: true)

      group.add_owner(user)
      sign_in(user)

      visit page_path
    end

    it 'has todo present' do
      expect(page).to have_selector('ol[data-testid="todo-item-list"] > li', count: 1)
      expect(page).to have_selector('a', text: user.to_reference)
    end
  end

  # TODO: Add spec for changes in https://gitlab.com/gitlab-org/gitlab/-/merge_requests/174883
end
