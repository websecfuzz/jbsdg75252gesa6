# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin GitLab Duo Setting', feature_category: :ai_abstraction_layer do
  before do
    admin = create(:admin)
    sign_in(admin)
    enable_admin_mode!(admin)
  end

  describe 'enable duo banner', :js, time_travel_to: '2025-05-15' do
    before do
      create(:license, plan: License::ULTIMATE_PLAN)
      visit admin_gitlab_duo_path
    end

    it_behaves_like 'admin interacts with enable duo banner sm'
  end
end
