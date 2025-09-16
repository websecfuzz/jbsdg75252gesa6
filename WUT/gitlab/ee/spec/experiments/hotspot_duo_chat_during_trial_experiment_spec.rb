# frozen_string_literal: true

require 'spec_helper'

RSpec.describe HotspotDuoChatDuringTrialExperiment, :experiment, feature_category: :activation do
  context 'with candidate experience' do
    before do
      stub_experiments(hotspot_duo_chat_during_trial: :candidate)
    end

    it 'does not raise' do
      expect(experiment(:hotspot_duo_chat_during_trial)).to register_behavior(:candidate).with(nil)
      expect { experiment(:hotspot_duo_chat_during_trial).run }.not_to raise_error
    end
  end

  context 'with control experience' do
    before do
      stub_experiments(hotspot_duo_chat_during_trial: :control)
    end

    it 'does not raise an error' do
      expect(experiment(:hotspot_duo_chat_during_trial)).to register_behavior(:control).with(nil)
      expect { experiment(:hotspot_duo_chat_during_trial).run }.not_to raise_error
    end
  end
end
