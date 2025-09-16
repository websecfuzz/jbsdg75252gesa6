# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CI shared runner settings', feature_category: :fleet_visibility do
  include StubENV

  let(:admin) { create(:admin) }
  let(:group) { create(:group, :with_ci_minutes, ci_minutes_limit: nil) }
  let!(:project) { create(:project, namespace: group, shared_runners_enabled: true) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(admin)
    enable_admin_mode!(admin)
  end

  context 'without global shared runners quota' do
    it 'displays ratio with global quota' do
      visit_admin_group_path
      expect(page).to have_content("Compute quota: 400 / Unlimited")
    end
  end

  context 'with global shared runners quota' do
    before do
      set_admin_shared_runners_minutes 500
    end

    it 'displays ratio with global quota' do
      visit_admin_group_path
      expect(page).to have_content("Compute quota: 400 / 500")
    end

    it 'displays new ratio with overridden group quota' do
      set_group_shared_runners_minutes 300
      visit_admin_group_path
      expect(page).to have_content("Compute quota: 400 / 300")
    end

    it 'displays unlimited ratio with overridden group quota' do
      set_group_shared_runners_minutes 0
      visit_admin_group_path
      expect(page).to have_content("Compute quota: 400 / Unlimited")
    end
  end

  def set_admin_shared_runners_minutes(limit)
    visit ci_cd_admin_application_settings_path

    within_testid('ci-cd-settings') do
      fill_in 'application_setting_shared_runners_minutes', with: limit
      click_on 'Save changes'
    end
  end

  def set_group_shared_runners_minutes(limit)
    visit admin_group_edit_path(group)
    fill_in 'group_shared_runners_minutes_limit', with: limit
    click_on 'Save changes'
  end

  def visit_admin_group_path
    visit admin_group_path(group)
  end
end
