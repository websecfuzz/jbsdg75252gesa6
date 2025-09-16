# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'users/registrations_identity_verification/success.html.haml', feature_category: :onboarding do
  let_it_be(:user) { create_default(:user) }

  before do
    allow(view).to receive(:current_user).and_return(user)
  end

  context 'when tracking_label is set' do
    before do
      assign(:tracking_label, '_tracking_label_')
    end

    it 'assigns the tracking items' do
      render

      expect(rendered).to have_tracking(action: 'render', label: '_tracking_label_')
    end
  end

  context 'when tracking_label is not set' do
    it 'does not assign the tracking items' do
      render

      expect(rendered).not_to have_tracking(action: 'render', label: '_tracking_label_')
    end
  end
end
