# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Members > Member leaves project', feature_category: :groups_and_projects do
  include Spec::Support::Helpers::ModalHelpers

  let(:user) { create(:user) }
  let(:project) { create(:project, :repository) }
  let(:more_actions_dropdown) do
    find_by_testid('groups-projects-more-actions-dropdown')
  end

  before do
    project.add_developer(user)
    project.add_developer(other_user)
    sign_in(user)
    visit project_path(project)
  end

  context 'when the user has been specifically allowed to access a protected branch' do
    let(:other_user) { create(:user) }
    let!(:matching_protected_branch) { create(:protected_branch, authorize_user_to_push: user, authorize_user_to_merge: user, project: project) }
    let!(:non_matching_protected_branch) { create(:protected_branch, authorize_user_to_push: other_user, authorize_user_to_merge: other_user, project: project) }

    context 'user leaves project' do
      it "removes the user's branch permissions", :js do
        more_actions_dropdown.click
        click_link 'Leave project'
        accept_gl_confirm(button_text: 'Leave project')

        expect(page).to have_current_path(dashboard_projects_path, ignore_query: true)
        expect(matching_protected_branch.push_access_levels.where(user: user)).not_to exist
        expect(matching_protected_branch.merge_access_levels.where(user: user)).not_to exist
        expect(non_matching_protected_branch.push_access_levels.where(user: other_user)).to exist
        expect(non_matching_protected_branch.merge_access_levels.where(user: other_user)).to exist
      end
    end
  end
end
