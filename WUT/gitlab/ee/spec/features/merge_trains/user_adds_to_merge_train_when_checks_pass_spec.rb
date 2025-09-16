# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User adds to merge train when all merge checks pass', :js, feature_category: :merge_trains do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user, :with_namespace) }

  let!(:merge_request) do
    create(:merge_request, :with_merge_request_pipeline,
      source_project: project, source_branch: 'feature',
      target_project: project, target_branch: 'master')
  end

  let(:pipeline) { merge_request.all_pipelines.first }

  before do
    stub_licensed_features(merge_pipelines: true, merge_trains: true)
    project.add_maintainer(user)
    project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true)

    merge_request.update_head_pipeline

    sign_in(user)
  end

  it 'shows Start merge train when all merge checks pass button and helper icon' do
    visit project_merge_request_path(project, merge_request)

    expect(page).to have_button('Set to auto-merge')
    expect(page).to have_selector('[data-testid="auto-merge-helper-text"]')

    within_testid('ready_to_merge_state') do
      find_by_testid('auto-merge-helper-text-icon').hover
    end

    expect(page).to have_link('merge train')
  end

  context 'when merge_trains EEP license is not available' do
    before do
      stub_licensed_features(merge_trains: false)
    end

    it 'does not show Start merge train when all merge checks pass button' do
      visit project_merge_request_path(project, merge_request)

      expect(page).to have_button('Set to auto-merge')
      expect(page).to have_content('Merge when all merge checks pass')
    end
  end

  context "when user clicks 'Start merge train when all merge checks pass' button" do
    before do
      visit project_merge_request_path(project, merge_request)
      click_button 'Set to auto-merge'

      wait_for_requests
    end

    it 'informs merge request that auto merge is enabled' do
      page.within('.mr-state-widget') do
        expect(page).to have_content("Set by #{user.name} to start a merge train when all merge checks pass")
        expect(page).to have_content('Source branch will not be deleted.')
        expect(page).to have_button('Cancel auto-merge')
      end
    end

    context "when user clicks 'Cancel' button" do
      before do
        click_button 'Cancel auto-merge'

        wait_for_requests
      end

      it 'cancels automatic merge' do
        page.within('.mr-state-widget') do
          expect(page).not_to have_content("Set by #{user.name} to start a merge train when all merge checks pass")
          expect(page).to have_button('Set to auto-merge')
          expect(page).to have_content('Add to merge train when all merge checks pass')
        end
      end
    end
  end

  context 'when the merge request is not the first queue on the train' do
    before do
      create(:merge_request, :on_train,
        source_project: project, source_branch: 'signed-commits',
        target_project: project, target_branch: 'master')
    end

    it 'shows Add to merge train when all merge checks pass button' do
      visit project_merge_request_path(project, merge_request)

      expect(page).to have_button('Set to auto-merge')
      expect(page).to have_content('Add to merge train when all merge checks pass')
    end
  end
end
