# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/registrations/new', feature_category: :system_access do
  let(:arkose_labs_enabled) { true }
  let(:arkose_labs_api_key) { "api-key" }
  let(:arkose_labs_domain) { "domain" }
  let(:resource) { Users::RegistrationsBuildService.new(nil, {}).execute }
  let(:params) { controller.params }
  let(:onboarding_status_presenter) do
    ::Onboarding::StatusPresenter.new(params.to_unsafe_h.deep_symbolize_keys, nil, resource)
  end

  subject { render && rendered }

  before do
    allow(view).to receive(:onboarding_status_presenter).and_return(onboarding_status_presenter)
    allow(view).to receive(:resource).and_return(resource)
    allow(view).to receive(:resource_name).and_return(:user)

    allow(view).to receive(:arkose_labs_enabled?).and_return(arkose_labs_enabled)
    allow(view).to receive(:preregistration_tracking_label).and_return('free_registration')
    allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_public_api_key)
      .and_return(arkose_labs_api_key)
    allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_labs_domain).and_return(arkose_labs_domain)
  end

  it { is_expected.to have_selector('#js-arkose-labs-challenge') }
  it { is_expected.to have_selector("[data-api-key='#{arkose_labs_api_key}']") }
  it { is_expected.to have_selector("[data-domain='#{arkose_labs_domain}']") }

  context 'when the feature is disabled' do
    let(:arkose_labs_enabled) { false }

    it { is_expected.not_to have_selector('#js-arkose-labs-challenge') }
    it { is_expected.not_to have_selector("[data-api-key='#{arkose_labs_api_key}']") }
    it { is_expected.not_to have_selector("[data-domain='#{arkose_labs_domain}']") }
  end

  context 'for password form' do
    before do
      controller.params[:glm_content] = '_glm_content_'
      controller.params[:glm_source] = '_glm_source_'
      stub_saas_features(onboarding: true)
    end

    it { is_expected.to have_css('form[action="/users?glm_content=_glm_content_&glm_source=_glm_source_"]') }
  end

  context 'for omniauth provider buttons' do
    before do
      allow(view).to receive(:providers).and_return([:github, :google_oauth2])
    end

    it { is_expected.to have_css('form[action="/users/auth/github"]') }
    it { is_expected.to have_css('form[action="/users/auth/google_oauth2"]') }

    context 'when saas onboarding feature is available' do
      let(:params) do
        controller.params.merge(glm_content: '_glm_content_', glm_source: '_glm_source_')
      end

      let(:action_params) { 'glm_content=_glm_content_&glm_source=_glm_source_&onboarding_status_email_opt_in=true' }

      before do
        stub_saas_features(onboarding: true)
      end

      it { is_expected.to have_css("form[action='/users/auth/github?#{action_params}']") }
      it { is_expected.to have_css("form[action='/users/auth/google_oauth2?#{action_params}']") }
    end
  end
end
