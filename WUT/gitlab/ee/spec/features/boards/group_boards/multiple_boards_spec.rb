# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Multiple Issue Boards', :js, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:planning) { create(:group_label, group: group, name: 'Planning') }
  let_it_be(:board) { create(:board, group: group, name: 'Board1') }
  let_it_be(:board2) { create(:board, group: group, name: 'Board2') }

  let(:parent) { group }
  let(:boards_path) { group_boards_path(group) }

  context 'with multiple group issue boards disabled' do
    before do
      stub_licensed_features(multiple_group_issue_boards: false)

      parent.add_maintainer(user)

      login_as(user)
    end

    it 'hides the link to create a new board' do
      visit boards_path
      wait_for_requests

      click_button board.name

      expect(page).not_to have_content('Create new board')
    end

    it 'does not show license warning when there is one board created',
      quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/409987' do
      visit boards_path
      wait_for_requests

      click_button board.name

      expect(page).not_to have_content('Some of your boards are hidden, add a license to see them again.')
    end

    it 'shows a license warning when group has more than one board' do
      create(:board, resource_parent: parent)

      visit boards_path
      wait_for_requests

      click_button board.name

      expect(page).to have_content('Some of your boards are hidden, add a license to see them again.')
    end
  end

  context 'with multiple group issue boards enabled' do
    before do
      stub_licensed_features(multiple_group_issue_boards: true)
    end

    it_behaves_like 'multiple issue boards'
  end
end
