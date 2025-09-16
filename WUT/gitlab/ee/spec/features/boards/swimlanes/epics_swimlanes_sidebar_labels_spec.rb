# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Issue boards sidebar labels using epic swimlanes', :js, feature_category: :portfolio_management do
  include BoardHelpers

  include_context 'labels from nested groups and projects'

  before do
    stub_licensed_features(epics: true, swimlanes: true)
  end

  let(:card) { find_by_testid('board-lane-unassigned-issues').first("[data-testid='board-card']") }

  context 'group boards' do
    context 'in the top-level group board' do
      let_it_be(:group_board) { create(:board, group: group) }
      let_it_be(:board_list) { group_board.lists.backlog.first }

      context 'when work item drawer is disabled' do
        before do
          stub_feature_flags(issues_list_drawer: false)
          load_board group_board_path(group, group_board)
          load_epic_swimlanes
          load_unassigned_issues
        end

        context 'selecting an issue from a direct descendant project' do
          let_it_be(:project_issue) { create(:issue, project: project) }

          include_examples 'an issue from a direct descendant project is selected'
        end

        context "selecting an issue from a subgroup's project" do
          let_it_be(:subproject_issue) { create(:issue, project: subproject) }

          include_examples "an issue from a subgroup's project is selected"
        end
      end

      context 'when work item drawer is enabled' do
        before do
          load_board group_board_path(group, group_board)
          load_epic_swimlanes
          load_unassigned_issues
        end

        context 'selecting an issue from a direct descendant project' do
          let_it_be(:project_issue) { create(:issue, project: project) }

          include_examples 'work item from a direct descendant project is selected'
        end

        context "selecting an issue from a subgroup's project" do
          let_it_be(:subproject_issue) { create(:issue, project: subproject) }

          include_examples "work item from a subgroup's project is selected"
        end
      end
    end
  end
end
