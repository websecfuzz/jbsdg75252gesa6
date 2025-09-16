# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightweightTrialRegistrationRedesignExperiment, :experiment, feature_category: :acquisition do
  let_it_be(:user, reload: true) { create_default(:user, onboarding_in_progress: true) }

  let(:exp) { experiment(:lightweight_trial_registration_redesign) }

  context 'with candidate experience' do
    before do
      stub_experiments(lightweight_trial_registration_redesign: :candidate)
    end

    it 'does not raise' do
      expect(exp).to register_behavior(:candidate).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end

  context 'with control experience' do
    before do
      stub_experiments(lightweight_trial_registration_redesign: :control)
    end

    it 'does not raise an error' do
      expect(exp).to register_behavior(:control).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end

  it "excludes user who already started trial registration" do
    expect(exp).to exclude(actor: user)
  end

  it "excludes non trial registrations" do
    user.update!(onboarding_status_version: 1, onboarding_status_initial_registration_type: '')
    expect(exp).to exclude(actor: user)
  end

  it "includes trial user on versioned onboarding flow" do
    user.update!(onboarding_status_version: 1, onboarding_status_initial_registration_type: 'trial')
    expect(exp).not_to exclude(actor: user)
  end

  it "includes not yet created user" do
    expect(exp).not_to exclude(actor: nil)
  end
end
