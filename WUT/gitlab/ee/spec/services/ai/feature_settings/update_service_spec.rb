# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureSettings::UpdateService, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
  let(:feature_setting) { create(:ai_feature_setting, provider: :vendored, self_hosted_model: nil) }

  let(:params) { { provider: :self_hosted, self_hosted_model: self_hosted_model } }

  subject(:service_result) { described_class.new(feature_setting, user, params).execute }

  describe '#execute' do
    let(:audit_event) do
      {
        name: 'self_hosted_model_feature_changed',
        author: user,
        scope: be_an_instance_of(Gitlab::Audit::InstanceScope),
        target: feature_setting,
        message: "Feature code_generations changed to Self-hosted model (mistral-7b-ollama-api)"
      }
    end

    it 'returns a success response' do
      expect(Gitlab::Audit::Auditor).to receive(:audit).with(audit_event)
      expect { service_result }.to change { feature_setting.reload.provider }.to("self_hosted")

      expect(service_result).to be_success
      expect(service_result.payload).to eq(feature_setting)
    end

    context 'when update fails' do
      let(:params) { { provider: '' } }

      it 'returns an error response' do
        expect(Gitlab::Audit::Auditor).not_to receive(:audit)

        expect(service_result).to be_error
        expect(service_result.message).to include("Provider can't be blank")
      end
    end
  end
end
