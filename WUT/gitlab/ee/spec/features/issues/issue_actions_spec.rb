# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Issue actions', :js, feature_category: :team_planning do
  # Ensure support bot user is created so creation doesn't count towards query limit
  # See https://gitlab.com/gitlab-org/gitlab/-/issues/509629
  let_it_be(:support_bot) { Users::Internal.support_bot }

  let(:group) { create(:group) }
  let(:project) { create(:project, group: group) }
  let(:issue) { create(:issue, project: project) }
  let(:user) { create(:user) }

  before do
    stub_feature_flags(work_item_view_for_issues: true)
    stub_licensed_features(epics: true)
    sign_in(user)
  end

  describe 'promote issue to epic action' do
    context 'when user is unauthorized' do
      before do
        group.add_guest(user)
        visit project_issue_path(project, issue)
      end

      it 'does not show "Promote to epic" item in issue actions dropdown' do
        click_button 'More actions', match: :first

        expect(page).not_to have_button 'Change type'
      end
    end

    context 'when user is authorized' do
      before do
        group.add_owner(user)
        visit project_issue_path(project, issue)
        # TODO: restore threshold after epic-work item sync
        # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/438295
        allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(125)
      end

      it 'clicking "Promote to epic" creates and redirects user to epic' do
        click_button 'More actions', match: :first
        click_button 'Change type'
        select 'Epic (Promote to group)', from: 'Type'
        click_button 'Change type'

        expect(page).to have_current_path(group_epic_path(group, 1))
      end
    end
  end
end
