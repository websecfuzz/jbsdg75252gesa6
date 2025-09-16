# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'trial_registrations/new', feature_category: :acquisition do
  let(:resource) { Users::AuthorizedBuildService.new(nil, {}).execute }
  let(:params) { controller.params }
  let(:onboarding_status_presenter) do
    ::Onboarding::StatusPresenter.new(params.to_unsafe_h.deep_symbolize_keys, nil, resource)
  end

  before do
    allow(view).to receive(:onboarding_status_presenter).and_return(onboarding_status_presenter)
    allow(view).to receive(:arkose_labs_enabled?).and_return(false)
    allow(view).to receive(:resource).and_return(resource)
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:preregistration_tracking_label).and_return('trial_registration')
    view.lookup_context.prefixes << 'devise/registrations'
  end

  subject { render && rendered }

  context 'when lightweight_trial_registration_redesign is control' do
    before do
      stub_experiments(lightweight_trial_registration_redesign: :control)
    end

    it { is_expected.to have_content(s_('InProductMarketing|Get Started with GitLab')) }
    it { is_expected.to have_content(s_('InProductMarketing|No credit card required.')) }
    it { is_expected.to have_content(s_('InProductMarketing|One platform for Dev, Sec, and Ops teams')) }

    it { is_expected.to have_content(_('First name')) }
    it { is_expected.to have_content(_('Last name')) }
    it { is_expected.to have_content(_('Username')) }

    it { is_expected.to have_content(_('Email')) }
    it { is_expected.to have_content(_('We recommend a work email address.')) }

    it { is_expected.to have_content(_('Password')) }

    it { is_expected.to have_content(s_('InProductMarketing|Want to host GitLab on your servers?')) }

    it 'has start self-managed link' do
      is_expected
        .to have_link(s_('InProductMarketing|Start with Self-Managed'), href: about_trial_url(hosted: 'self-managed'))
    end
  end

  context 'when lightweight_trial_registration_redesign is candidate' do
    before do
      stub_experiments(lightweight_trial_registration_redesign: :candidate)
    end

    it { is_expected.to have_content(s_('InProductMarketing|Get Started with GitLab')) }

    it { is_expected.not_to have_content(_('First name')) }
    it { is_expected.not_to have_content(_('Last name')) }

    it { is_expected.to have_content(_('Company email')) }
    it { is_expected.not_to have_content(_('We recommend a work email address.')) }

    it { is_expected.not_to have_content(_('Must be between 8-128 characters')) }
    it { is_expected.not_to have_content(_('Cannot use common phrases (e.g. "password")')) }
    it { is_expected.not_to have_content(_('Cannot include your name, username, or email')) }

    it { is_expected.to have_content(s_('InProductMarketing|Want to host GitLab on your servers?')) }
    it { is_expected.to have_link(s_('InProductMarketing|Start a Self-Managed trial'), href: 'https://about.gitlab.com/free-trial/#selfmanaged/') }
  end

  context 'for password form' do
    before do
      allow(view).to receive(:social_signin_enabled?).and_return(true)
      controller.params[:glm_content] = '_glm_content_'
      controller.params[:glm_source] = '_glm_source_'
      stub_saas_features(onboarding: true)
    end

    it do
      is_expected.to have_css('form[action="/-/trial_registrations?glm_content=_glm_content_&glm_source=_glm_source_"]')
    end
  end

  context 'for omniauth provider buttons' do
    let(:params) do
      controller.params.merge(glm_content: '_glm_content_', glm_source: '_glm_source_')
    end

    let(:action_params) do
      'glm_content=_glm_content_&glm_source=_glm_source_&onboarding_status_email_opt_in=true&trial=true'
    end

    before do
      allow(view).to receive(:social_signin_enabled?).and_return(true)
      allow(view).to receive(:popular_enabled_button_based_providers).and_return([:github, :google_oauth2])
      stub_saas_features(onboarding: true) # for trials this view it isn't reachable in the false case
    end

    it { is_expected.to have_css("form[action='/users/auth/github?#{action_params}']") }
    it { is_expected.to have_css("form[action='/users/auth/google_oauth2?#{action_params}']") }
  end
end
