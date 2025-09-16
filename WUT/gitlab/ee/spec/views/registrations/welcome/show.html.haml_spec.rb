# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'registrations/welcome/show', feature_category: :onboarding do
  let(:hide_setup_for_company_field?) { false }
  let(:show_joining_project?) { true }
  let(:onboarding_status_presenter) do
    instance_double(
      ::Onboarding::StatusPresenter,
      hide_setup_for_company_field?: hide_setup_for_company_field?,
      setup_for_company_label_text: '_text_',
      setup_for_company_help_text: '_help_text_',
      show_joining_project?: show_joining_project?,
      welcome_submit_button_text: '_button_text_',
      tracking_label: 'free_registration'
    )
  end

  before do
    allow(view).to receive(:onboarding_status_presenter).and_return(onboarding_status_presenter)
    allow(view).to receive(:current_user).and_return(build_stubbed(:user))

    render
  end

  subject { rendered }

  context 'with basic form items' do
    it do
      is_expected.to have_css('form[action="/users/sign_up/welcome"]')
    end

    it { is_expected.to have_tracking(action: 'render', label: 'free_registration') }

    it 'the text for the :onboarding_status_setup_for_company label' do
      is_expected.to have_selector('label[for="user_onboarding_status_setup_for_company"]', text: '_text_')
    end

    it 'shows the text for the submit button' do
      is_expected.to have_button('_button_text_')
    end

    it 'has the joining_project fields', :aggregate_failures do
      is_expected.to have_selector('#user_onboarding_status_joining_project_true')
      is_expected.to have_selector('#user_onboarding_status_joining_project_false')
    end

    it 'renders a select and text field for additional information' do
      is_expected.to have_selector('select[name="user[onboarding_status_registration_objective]"]')
      is_expected.to have_selector('input[name="jobs_to_be_done_other"]', visible: false)
    end
  end

  context 'when setup for company field should be hidden' do
    let(:hide_setup_for_company_field?) { true }

    it 'does not have _onboarding_status_setup_for_company label' do
      is_expected.not_to have_selector('label[for="user_onboarding_status_setup_for_company"]')
    end

    it 'the text for the :_onboarding_status_setup_for_company help text' do
      is_expected.not_to have_text('_help_text_')
    end

    it 'has a hidden input for onboarding_status_setup_for_company' do
      is_expected.to have_field('user[onboarding_status_setup_for_company]', type: :hidden)
    end
  end

  context 'when not showing joining project' do
    let(:show_joining_project?) { false }

    it 'does not have the joining_project fields' do
      is_expected.not_to have_selector('#joining_project_true')
    end
  end

  context 'when setup for company field is not hidden' do
    let(:hide_setup_for_company_field?) { false }

    it 'has onboarding_status_setup_for_company label' do
      is_expected.to have_selector('label[for="user_onboarding_status_setup_for_company"]')
    end

    it 'the text for the :onboarding_status_setup_for_company help text' do
      is_expected.to have_text('_help_text_')
    end
  end
end
