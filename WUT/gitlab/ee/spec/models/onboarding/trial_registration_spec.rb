# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::TrialRegistration, type: :undefined, feature_category: :onboarding do
  subject { described_class }

  describe '.tracking_label' do
    subject { described_class.tracking_label }

    it { is_expected.to eq('trial_registration') }
  end

  describe '.product_interaction' do
    subject { described_class.product_interaction }

    it { is_expected.to eq('SaaS Trial') }
  end

  describe '.welcome_submit_button_text' do
    subject { described_class.welcome_submit_button_text }

    it { is_expected.to eq(_('Continue')) }
  end

  describe '.setup_for_company_label_text' do
    subject { described_class.setup_for_company_label_text }

    it { is_expected.to eq(_('Who will be using this GitLab trial?')) }
  end

  describe '.setup_for_company_help_text' do
    subject { described_class.setup_for_company_help_text }

    it { is_expected.to be_nil }
  end

  describe '.show_company_form_footer?' do
    subject { described_class.show_company_form_footer? }

    it { is_expected.to be(false) }
  end

  describe '.learn_gitlab_redesign?' do
    it { is_expected.to be_learn_gitlab_redesign }
  end

  describe '.show_company_form_side_column?' do
    it { is_expected.not_to be_show_company_form_side_column }
  end

  describe '.redirect_to_company_form?' do
    it { is_expected.to be_redirect_to_company_form }
  end

  describe '.eligible_for_iterable_trigger?' do
    it { is_expected.not_to be_eligible_for_iterable_trigger }
  end

  describe '.continue_full_onboarding?' do
    it { is_expected.to be_continue_full_onboarding }
  end

  describe '.convert_to_automatic_trial?' do
    it { is_expected.not_to be_convert_to_automatic_trial }
  end

  describe '.show_joining_project?' do
    it { is_expected.not_to be_show_joining_project }
  end

  describe '.hide_setup_for_company_field?' do
    it { is_expected.not_to be_hide_setup_for_company_field }
  end

  describe '.apply_trial?' do
    it { is_expected.to be_apply_trial }
  end

  describe '.read_from_stored_user_location?' do
    it { is_expected.not_to be_read_from_stored_user_location }
  end

  describe '.preserve_stored_location?' do
    it { is_expected.not_to be_preserve_stored_location }
  end

  describe '.ignore_oauth_in_welcome_submit_text?' do
    it { is_expected.not_to be_ignore_oauth_in_welcome_submit_text }
  end
end
