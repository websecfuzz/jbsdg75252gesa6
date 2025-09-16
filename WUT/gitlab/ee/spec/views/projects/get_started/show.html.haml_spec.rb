# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/get_started/show', :aggregate_failures, feature_category: :onboarding do
  let(:hide_trial_alert?) { false }

  before do
    onboarding_progress = build_stubbed(:onboarding_progress)

    assign(:get_started_presenter, instance_double(Onboarding::GetStartedPresenter, attributes: '{"sections":[]}'))
    allow(view).to receive_messages(onboarding_progress: onboarding_progress, current_user: build_stubbed(:user))
    allow(view)
      .to receive(:hide_unlimited_members_during_trial_alert?).with(onboarding_progress).and_return(hide_trial_alert?)

    render
  end

  it 'hides broadcast messages' do
    expect(view.content_for(:hide_broadcast_messages)).to be_truthy
  end

  context 'when unlimited members during trial alert should be hidden' do
    let(:hide_trial_alert?) { true }

    it 'hides unlimited members during trial alert' do
      expect(view.content_for(:hide_unlimited_members_during_trial_alert)).to be_truthy
    end
  end

  context 'when unlimited members during trial alert should be shown' do
    it 'does not hide unlimited members during trial alert' do
      expect(view.content_for(:hide_unlimited_members_during_trial_alert)).to be_falsey
    end
  end

  it 'renders the get started app container' do
    expect(rendered).to have_css('#js-get-started-app')
  end

  it 'passes the presenter attributes to the frontend' do
    expect(rendered).to have_css('#js-get-started-app[data-view-model=\'{"sections":[]}\']')
  end
end
