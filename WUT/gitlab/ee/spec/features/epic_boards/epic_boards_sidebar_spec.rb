# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic boards sidebar', :js, feature_category: :portfolio_management do
  include BoardHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }

  let_it_be(:bug) { create(:group_label, group: group, name: 'Bug') }
  let_it_be(:epic_board) { create(:epic_board, group: group) }
  let_it_be(:backlog_list) { create(:epic_list, epic_board: epic_board, list_type: :backlog) }
  let_it_be(:closed_list) { create(:epic_list, epic_board: epic_board, list_type: :closed) }
  let_it_be(:epic1) { create(:epic, group: group, title: 'Epic1') }

  let(:card) { find('[data-testid="board-list"]:nth-child(1)').first("[data-testid='board-card']") }

  before do
    stub_licensed_features(epics: true)
    group.add_maintainer(user)
  end

  context 'when work item drawer is disabled' do
    before do
      stub_feature_flags(epics_list_drawer: false)
      sign_in(user)

      visit group_epic_boards_path(group)
      wait_for_requests
    end

    it 'shows sidebar when clicking epic' do
      click_card(card)

      expect(page).to have_selector('[data-testid="epic-boards-sidebar"]')
    end

    it 'closes sidebar when clicking epic' do
      click_card(card)

      expect(page).to have_selector('[data-testid="epic-boards-sidebar"]')

      click_card(card)

      expect(page).not_to have_selector('[data-testid="epic-boards-sidebar"]')
    end

    it 'closes sidebar when clicking close button' do
      click_card(card)

      expect(page).to have_selector('[data-testid="epic-boards-sidebar"]')

      find('.gl-drawer-close-button [data-testid="close-icon"]').click

      expect(page).not_to have_selector('[data-testid="epic-boards-sidebar"]')
    end

    it 'shows epic details when sidebar is open', :aggregate_failures do
      click_card(card)

      within_testid('epic-boards-sidebar') do
        expect(page).to have_content(epic1.title)
        expect(page).to have_content(epic1.to_reference)
      end
    end

    context 'title' do
      it 'edits epic title' do
        click_card(card)

        within_testid('sidebar-title') do
          click_button 'Edit'

          wait_for_requests

          find('input').set('Test title')

          click_button 'Save changes'

          wait_for_requests

          expect(page).to have_content('Test title')
        end

        expect(card).to have_content('Test title')
      end
    end

    context 'todo' do
      it 'creates todo when clicking button' do
        click_card(card)
        wait_for_requests

        within_testid('sidebar-todo') do
          click_button 'Add a to-do item'
          wait_for_requests

          expect(page).to have_content 'Mark as done'
        end
      end

      it 'marks a todo as done' do
        click_card(card)
        wait_for_requests

        within_testid('sidebar-todo') do
          click_button 'Add a to-do item'
          wait_for_requests
          click_button 'Mark as done'
          wait_for_requests
          expect(page).to have_content 'Add a to-do item'
        end
      end
    end

    context 'confidentiality' do
      it 'make epic confidential' do
        click_card(card)

        page.within('.confidentiality') do
          expect(page).to have_content('Not confidential')

          click_button 'Edit'
          expect(page).to have_css('.sidebar-item-warning-message')

          within('.sidebar-item-warning-message') do
            click_button 'Turn on'
          end

          wait_for_requests

          expect(page).to have_content(
            _('Only group members with at least ' \
            'the Planner role can view or be ' \
            'notified about this epic')
          )
        end
      end
    end

    context 'in notifications subscription' do
      it 'displays notifications toggle', :aggregate_failures do
        click_card(card)

        expect(page).to have_selector('[data-testid="subscription-toggle"]')
      end

      it 'shows toggle as on then as off as user toggles to subscribe and unsubscribe', :aggregate_failures do
        click_card(card)

        wait_for_requests

        subscription_button = find_by_testid('subscription-toggle')

        subscription_button.find('button').click

        wait_for_requests

        expect(subscription_button).to have_css("button.is-checked")

        subscription_button.find('button').click

        wait_for_requests

        expect(subscription_button).to have_css("button:not(.is-checked)")
      end

      context 'when notifications have been disabled' do
        before do
          group.update_attribute(:emails_enabled, false)

          refresh_and_click_first_card
        end

        it 'displays a message that notifications have been disabled' do
          page.within('.subscriptions') do
            expect(page).to have_selector('[data-testid="subscription-toggle"]', class: 'is-disabled')
            expect(page).to have_content('Disabled by group owner')
          end
        end
      end
    end
  end

  context 'when work item drawer is enabled' do
    before do
      sign_in(user)

      visit group_epic_boards_path(group)
      wait_for_requests
    end

    it 'shows work item drawer when clicking epic' do
      click_card(card)

      expect(page).to have_selector('[data-testid="work-item-drawer"]')
    end

    it 'closes work item drawer when clicking epic' do
      click_card(card)

      expect(page).to have_selector('[data-testid="work-item-drawer"]')

      click_card(card)

      expect(page).not_to have_selector('[data-testid="work-item-drawer"]')
    end

    it 'closes work item drawer when clicking close button' do
      click_card(card)

      expect(page).to have_selector('[data-testid="work-item-drawer"]')

      within_testid('work-item-drawer') do
        find('.gl-drawer-close-button [data-testid="close-icon"]').click
      end

      expect(page).not_to have_selector('[data-testid="work-item-drawer"]')
    end

    it 'shows epic details when drawer is open', :aggregate_failures do
      click_card(card)

      within_testid('work-item-drawer') do
        expect(page).to have_content(epic1.title)
      end
    end

    context 'title' do
      it 'edits epic title' do
        click_card(card)

        within_testid('work-item-drawer') do
          find_by_testid('work-item-edit-form-button').click

          wait_for_requests

          find_by_testid('work-item-title-input').set('Test title')

          click_button 'Save changes'

          wait_for_requests

          expect(page).to have_content('Test title')
        end

        expect(card).to have_content('Test title')
      end
    end

    context 'todo' do
      it 'creates todo when clicking button', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/501253' do
        click_card(card)
        wait_for_requests

        within_testid('work-item-drawer') do
          click_button 'Add a to-do item'
          wait_for_requests

          expect(page).to have_selector('button[title="Mark as done"]')
        end
      end

      it 'marks a todo as done', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/484463' do
        click_card(card)
        wait_for_requests

        within_testid('work-item-drawer') do
          click_button 'Add a to-do item'
          wait_for_requests
          click_button 'Mark as done'
          wait_for_requests
          expect(page).to have_selector('button[title="Add a to-do item"]')
        end
      end
    end

    context 'dates' do
      before do
        click_card(card)
        wait_for_requests
      end

      it_behaves_like 'work items due dates in drawer'
    end

    context 'confidentiality' do
      it 'make epic confidential' do
        click_card(card)

        within_testid('work-item-actions-dropdown') do
          find('button').click
          find('li', text: 'Turn on confidentiality').click
          wait_for_requests
        end

        within_testid('work-item-drawer') do
          expect(page).to have_content('Confidential')
        end
      end
    end

    context 'in notifications subscription' do
      it 'displays notifications toggle', :aggregate_failures do
        click_card(card)

        within_testid('work-item-actions-dropdown') do
          find('button').click

          expect(page).to have_selector('[data-testid="notifications-toggle-form"]')
        end
      end

      it 'shows toggle as on then as off as user toggles to subscribe and unsubscribe', :aggregate_failures do
        click_card(card)

        wait_for_requests

        within_testid('work-item-actions-dropdown') do
          find('button').click

          within_testid('notifications-toggle-form') do
            subscription_button = find_by_testid('notifications-toggle').find('button')

            subscription_button.click

            wait_for_requests

            expect(page).to have_selector('button.is-checked')

            subscription_button.click

            wait_for_requests

            expect(page).not_to have_selector('button.is-checked')
          end
        end
      end
    end
  end

  def refresh_and_click_first_card
    page.refresh

    wait_for_requests

    click_card(card)
  end

  def pick_a_date
    click_button 'Edit'

    expect(page).to have_selector('.gl-datepicker')
    page.within('.pika-lendar') do
      click_button '25'
    end

    wait_for_requests
  end

  def edit_fixed_date
    within_testid('sidebar-inherited-date') do
      expect(find_field('Inherited:')).to be_checked
    end

    pick_a_date

    within_testid('sidebar-fixed-date') do
      expect(find_by_testid('sidebar-date-value').text).to include('25')
      expect(find_field('Fixed:')).to be_checked
    end
  end

  def remove_fixed_date
    expect(page).not_to have_button('remove')
    within_testid('sidebar-fixed-date') do
      expect(find_by_testid('sidebar-date-value').text).to include('None')
    end

    pick_a_date

    within_testid('sidebar-fixed-date') do
      expect(find_by_testid('sidebar-date-value').text).not_to include('None')

      expect(page).to have_button('remove')
      find_button('remove').click

      wait_for_requests
      expect(page).not_to have_button('remove')
      expect(find_by_testid('sidebar-date-value').text).to include('None')
    end
  end
end
