# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ai::SelfHosted::AiGateway, feature_category: :"self-hosted_models" do
  describe '.probes' do
    let(:user) { build(:user) }

    it 'returns an array with all expected probe instances' do
      probes = described_class.probes(user)

      expect(probes).to contain_exactly(
        an_instance_of(::CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe),
        an_instance_of(::CloudConnector::StatusChecks::Probes::HostProbe),
        an_instance_of(::CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe)
      )
    end
  end
end
