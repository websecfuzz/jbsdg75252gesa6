# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Root cause analysis job page', :saas, :js, feature_category: :continuous_integration do
  let(:user) { create(:user) }
  let(:group) { create(:group_with_plan, plan: :ultimate_plan, owners: user) }
  let(:project) { create(:project, :repository, namespace: group) }
  let(:passed_job) { create(:ci_build, :success, :trace_live, project: project) }
  let(:failed_job) { create(:ci_build, :failed, :trace_live, project: project) }

  before do
    stub_licensed_features(troubleshoot_job: true)

    project.add_developer(user)
    sign_in(user)
  end

  context 'with duo enterprise license' do
    include_context 'with duo enterprise addon'

    context 'with failed jobs' do
      before do
        visit(project_job_path(project, failed_job))

        wait_for_requests
      end

      it 'does display rca with duo button' do
        expect(page).to have_selector("[data-testid='rca-duo-button']")
      end
    end
  end
end
