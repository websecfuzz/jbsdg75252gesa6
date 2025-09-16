# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/sessions/successful_verification', feature_category: :onboarding do
  context 'with a user during trial registration', :experiment do
    let(:user) do
      create_default(:user, onboarding_in_progress: true, onboarding_status_initial_registration_type: 'trial',
        onboarding_status_version: 1)
    end

    before do
      allow(view).to receive(:current_user).and_return(user)
    end

    it 'runs experiment' do
      stub_experiments(lightweight_trial_registration_redesign: :control)

      render

      expect(response).to have_content("Verification successful")

      experiment(:lightweight_trial_registration_redesign, actor: user) do |e|
        expect(e.assigned.name).to eq(:control)
      end
    end

    it 'runs experiment' do
      stub_experiments(lightweight_trial_registration_redesign: :candidate)

      render

      expect(response).to have_content("Verification successful")

      experiment(:lightweight_trial_registration_redesign, actor: user) do |e|
        expect(e.assigned.name).to eq(:candidate)
      end
    end
  end
end
