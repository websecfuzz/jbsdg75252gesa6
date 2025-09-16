# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GFM autocomplete', :js, feature_category: :portfolio_management do
  include Features::AutocompleteHelpers

  let_it_be(:user) { create(:user, name: '💃speciąl someone💃', username: 'someone.special') }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:epic) { create(:epic, group: group) }

  before do
    stub_licensed_features(epics: true)
    sign_in(user)
  end

  context 'for a new epic' do
    let_it_be(:label) { create(:group_label, group: group) }

    before do
      visit new_group_epic_path(group)
      wait_for_requests
    end

    it 'opens quick action autocomplete in the description field' do
      fill_in 'Description', with: '/la'

      expect(find_highlighted_autocomplete_item).to have_text('/label')
    end
  end

  context 'for an existing epic' do
    before do
      visit group_epic_path(group, epic)

      wait_for_requests
    end

    it 'opens quick action autocomplete when updating description' do
      click_button 'Edit title and description'

      fill_in 'Description', with: '/'

      expect(find_autocomplete_menu).to be_visible
    end

    describe 'issuables' do
      let(:project) { create(:project, :repository, namespace: group) }

      describe 'issues' do
        it 'shows issues of group' do
          issue_1 = create(:issue, project: project)
          issue_2 = create(:issue, project: project)

          fill_in _('Add a reply'), with: '#'

          expect_resources(shown: [issue_1, issue_2, epic.work_item])
        end
      end

      describe 'merge requests' do
        it 'shows merge requests of group' do
          mr_1 = create(:merge_request, source_project: project)
          mr_2 = create(:merge_request, source_project: project, source_branch: 'other-branch')

          fill_in _('Add a reply'), with: '!'

          expect_resources(shown: [mr_1, mr_2])
        end
      end
    end

    describe 'epics' do
      let!(:epic2) { create(:epic, group: group, title: 'make tea') }

      it 'shows epics' do
        fill_in _('Add a reply'), with: '&'

        expect_resources(shown: [epic, epic2])
      end
    end

    describe 'milestone' do
      it 'shows group milestones' do
        project = create(:project, namespace: group)
        milestone_1 = create(:milestone, title: 'milestone_1', group: group)
        milestone_2 = create(:milestone, title: 'milestone_2', group: group)
        milestone_3 = create(:milestone, title: 'milestone_3', project: project)

        fill_in _('Add a reply'), with: '%'

        expect_resources(shown: [milestone_1, milestone_2], not_shown: [milestone_3])
      end
    end

    describe 'labels' do
      let_it_be(:backend) { create(:group_label, group: group, title: 'backend') }
      let_it_be(:bug) { create(:group_label, group: group, title: 'bug') }
      let_it_be(:feature_proposal) { create(:group_label, group: group, title: 'feature proposal') }

      context 'when no labels are assigned' do
        it 'shows all labels for ~' do
          fill_in _('Add a reply'), with: '~'

          wait_for_requests

          expect_resources(shown: [backend, bug, feature_proposal])
        end

        it 'shows all labels for /label ~' do
          fill_in _('Add a reply'), with: '/label ~'

          wait_for_requests

          expect_resources(shown: [backend, bug, feature_proposal])
        end

        it 'shows all labels for /relabel ~' do
          fill_in _('Add a reply'), with: '/relabel ~'

          wait_for_requests

          expect_resources(shown: [backend, bug, feature_proposal])
        end

        it 'shows no labels for /unlabel ~' do
          fill_in _('Add a reply'), with: '/unlabel ~'

          wait_for_requests

          expect_resources(not_shown: [backend, bug, feature_proposal])
        end
      end

      context 'when some labels are assigned' do
        before do
          epic.labels << [backend]
        end

        it 'shows all labels for ~' do
          fill_in _('Add a reply'), with: '~'

          wait_for_requests

          expect_resources(shown: [backend, bug, feature_proposal])
        end

        it 'shows only unset labels for /label ~', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/449075' do
          fill_in _('Add a reply'), with: '/label ~'

          wait_for_requests

          expect_resources(shown: [bug, feature_proposal], not_shown: [backend])
        end

        it 'shows all labels for /relabel ~' do
          fill_in _('Add a reply'), with: '/relabel ~'

          wait_for_requests

          expect_resources(shown: [backend, bug, feature_proposal])
        end

        it 'shows only set labels for /unlabel ~', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/444686' do
          fill_in _('Add a reply'), with: '/unlabel ~'

          wait_for_requests

          expect_resources(shown: [backend], not_shown: [bug, feature_proposal])
        end
      end

      context 'when all labels are assigned' do
        before do
          epic.labels << [backend, bug, feature_proposal]
        end

        it 'shows all labels for ~' do
          fill_in _('Add a reply'), with: '~'

          wait_for_requests

          expect_resources(shown: [backend, bug, feature_proposal])
        end

        it 'shows no labels for /label ~', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/449075' do
          fill_in _('Add a reply'), with: '/label ~'

          wait_for_requests

          expect_resources(not_shown: [backend, bug, feature_proposal])
        end

        it 'shows all labels for /relabel ~' do
          fill_in _('Add a reply'), with: '/relabel ~'

          wait_for_requests

          expect_resources(shown: [backend, bug, feature_proposal])
        end

        it 'shows all labels for /unlabel ~', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/456464' do
          fill_in _('Add a reply'), with: '/unlabel ~'
          wait_for_requests

          expect_resources(shown: [backend, bug, feature_proposal])
        end
      end
    end
  end

  private

  def expect_resources(shown: nil, not_shown: nil)
    # rubocop: disable RSpec/AvoidConditionalStatements -- needs refactoring into separate methods
    page.within('.atwho-container') do
      if shown
        expect(page).to have_selector('.atwho-view li', count: shown.size)
        shown.each { |resource| expect(page).to have_content(resource.title) }
      end

      if not_shown
        expect(page).not_to have_selector('.atwho-view li') unless shown
        not_shown.each { |resource| expect(page).not_to have_content(resource.title) }
      end
    end
    # rubocop: enable RSpec/AvoidConditionalStatements
  end
end
