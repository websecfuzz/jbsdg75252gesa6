# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoPro::TrialFormWithErrorsComponent, :saas, :aggregate_failures, type: :component, feature_category: :acquisition do
  let(:errors) { ['some CDOT error'] }
  let(:reason) { nil }
  let(:additional_kwargs) { { errors: errors, reason: reason } }

  it_behaves_like GitlabSubscriptions::Trials::DuoPro::TrialFormComponent do
    it { is_expected.to have_text('some CDOT error') }

    context 'when it is a generic error' do
      let(:reason) { GitlabSubscriptions::Trials::BaseApplyTrialService::GENERIC_TRIAL_ERROR }

      it { is_expected.to have_text('Please reach out to GitLab Support for assistance: some CDOT error') }
    end
  end
end
