# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/security_and_compliance.html.haml', feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { build_stubbed(:admin) }
  let_it_be(:app_settings) { build(:application_setting) }

  subject { rendered }

  before do
    assign(:application_setting, app_settings)
    allow(view).to receive(:current_user).and_return(user)

    stub_licensed_features(secret_push_protection: feature_available)
  end

  shared_examples 'renders secret push protection setting' do
    it do
      render

      expect(rendered).to have_css('[data-testid="admin-secret-detection-settings"]')
    end
  end

  shared_examples 'does not render secret push protection setting' do
    it do
      render

      expect(rendered).not_to have_css('[data-testid="admin-secret-detection-settings"]')
    end
  end

  describe 'feature available' do
    let(:feature_available) { true }

    it_behaves_like 'renders secret push protection setting'
  end

  describe 'feature not available' do
    let(:feature_available) { false }

    it_behaves_like 'does not render secret push protection setting'
  end
end
