# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/milestones/_issuable.html.haml', feature_category: :groups_and_projects do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:project) { build_stubbed(:project, group: group) }
  let_it_be(:milestone) { build_stubbed(:milestone, group: group) }

  subject(:rendered) { render 'shared/milestones/issuable', issuable: issuable, show_project_name: true }

  context 'when issuable is an epic' do
    let(:issuable) { build_stubbed(:work_item, :epic_with_legacy_epic, :group_level, namespace: group) }

    it 'links to the epic' do
      expect(rendered).to have_css("a[href$='#{group_epic_path(group, issuable)}']", class: 'issue-link')
    end
  end
end
