# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Incidents > User uses EE quick actions', :js, feature_category: :incident_management do
  include Features::NotesHelpers

  describe 'incident-only commands' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }
    let_it_be(:incident, reload: true) { create(:incident, project: project) }

    let_it_be(:escalation_policy) do
      create(:incident_management_escalation_policy, project: project, name: 'spec policy')
    end

    let_it_be(:escalation_status, reload: true) do
      create(:incident_management_issuable_escalation_status, issue: incident)
    end

    before do
      project.add_developer(user)
      sign_in(user)
      visit project_issue_path(project, incident)
      wait_for_all_requests
    end

    after do
      wait_for_requests
    end

    it_behaves_like 'zoom quick actions ee'
    it_behaves_like 'link quick actions'
    it_behaves_like 'status page quick actions'
    it_behaves_like 'page quick action'
  end
end
