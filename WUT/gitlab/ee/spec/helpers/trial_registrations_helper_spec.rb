# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TrialRegistrationsHelper, feature_category: :subscription_management do
  using RSpec::Parameterized::TableSyntax

  describe '#social_signin_enabled?' do
    before do
      stub_saas_features(onboarding: onboarding_enabled)
      allow(view).to receive(:omniauth_enabled?).and_return(omniauth_enabled)
      allow(view).to receive(:button_based_providers_enabled?).and_return(button_based_providers_enabled)
      allow(view).to receive(:devise_mapping).and_return(instance_double(Devise::Mapping, omniauthable?: omniauthable))
    end

    subject { helper.social_signin_enabled? }

    where onboarding_enabled: [true, false],
      omniauth_enabled: [true, false],
      omniauthable: [true, false],
      button_based_providers_enabled: [true, false]

    with_them do
      let(:result) { onboarding_enabled && omniauth_enabled && button_based_providers_enabled && omniauthable }

      it { is_expected.to eq(result) }
    end
  end
end
