# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'issue resource weight events', :js, feature_category: :team_planning do
  let(:user)     { create(:user) }
  let(:project)  { create(:project, :public) }
  let(:issue)    { create(:issue, project: project, author: user) }

  context 'when user displays the issue' do
    let!(:note) { create(:note_on_issue, author: user, project: project, noteable: issue, note: 'some note') }
    let!(:event1) { create(:resource_weight_event, issue: issue, weight: 1) }
    let!(:event2) { create(:resource_weight_event, issue: issue, weight: 5) }

    before do
      stub_feature_flags(work_item_view_for_issues: true)
      visit project_issue_path(project, issue)
    end

    it 'shows both notes and resource weight event synthetic notes' do
      expect(find("#note_#{note.id}")).to have_content 'some note'
      expect(page).to have_content 'set weight to 1', count: 1
      expect(page).to have_content 'set weight to 5', count: 1
    end
  end
end
