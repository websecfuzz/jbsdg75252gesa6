# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::SubscriptionRegistration, type: :undefined, feature_category: :onboarding do
  subject { described_class }

  describe '.tracking_label' do
    subject { described_class.tracking_label }

    it { is_expected.to eq('subscription_registration') }
  end

  describe '.welcome_submit_button_text' do
    subject { described_class.welcome_submit_button_text }

    it { is_expected.to eq(_('Continue')) }
  end

  describe '.setup_for_company_label_text' do
    subject { described_class.setup_for_company_label_text }

    it { is_expected.to eq(_('Who will be using this GitLab subscription?')) }
  end

  describe '.setup_for_company_help_text' do
    subject { described_class.setup_for_company_help_text }

    it { is_expected.to be_nil }
  end

  describe '.redirect_to_company_form?' do
    it { is_expected.not_to be_redirect_to_company_form }
  end

  describe '.eligible_for_iterable_trigger?' do
    it { is_expected.not_to be_eligible_for_iterable_trigger }
  end

  describe '.continue_full_onboarding?' do
    it { is_expected.not_to be_continue_full_onboarding }
  end

  describe '.convert_to_automatic_trial?' do
    it { is_expected.not_to be_convert_to_automatic_trial }
  end

  describe '.show_joining_project?' do
    it { is_expected.to be_show_joining_project }
  end

  describe '.hide_setup_for_company_field?' do
    it { is_expected.not_to be_hide_setup_for_company_field }
  end

  describe '.read_from_stored_user_location?' do
    it { is_expected.to be_read_from_stored_user_location }
  end

  describe '.preserve_stored_location?' do
    it { is_expected.to be_preserve_stored_location }
  end

  describe '.ignore_oauth_in_welcome_submit_text?' do
    it { is_expected.to be_ignore_oauth_in_welcome_submit_text }
  end
end
