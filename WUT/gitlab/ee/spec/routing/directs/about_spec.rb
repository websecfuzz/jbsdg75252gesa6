# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'About site URLs', 'about', feature_category: :shared do
  describe 'about_trial_url' do
    subject { about_trial_url }

    it { is_expected.to eq("#{about_url}/free-trial") }

    context 'with params' do
      subject { about_trial_url(hosted: 'self-managed') }

      it { is_expected.to eq("#{about_url}/free-trial?hosted=self-managed") }
    end
  end
end
