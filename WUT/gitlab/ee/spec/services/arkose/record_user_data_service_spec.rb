# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arkose::RecordUserDataService, feature_category: :instance_resiliency do
  let_it_be(:user) { create(:user) }

  let(:arkose_verify_response) do
    Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/successfully_solved_ec_response.json')))
  end

  let(:response) { Arkose::VerifyResponse.new(arkose_verify_response) }
  let(:service) { described_class.new(response: response, user: user) }
  let(:user_scores) { AntiAbuse::UserTrustScore.new(user) }

  describe '#execute' do
    it 'adds new custom attributes to the user' do
      expect { service.execute }.to change { user.custom_attributes.count }.from(0).to(5)
    end

    it 'adds arkose data to custom attributes' do
      service.execute

      expect(user.custom_attributes.find_by(key: 'arkose_session').value).to eq('22612c147bb418c8.2570749403')
      expect(user.custom_attributes.find_by(key: 'arkose_device_id').value).to eq('gaFCZkxoGZYW6')
      expect(
        user.custom_attributes.find_by(key: UserCustomAttribute::ARKOSE_RISK_BAND).value
      ).to eq(Arkose::VerifyResponse::RISK_BAND_LOW)
      expect(user.custom_attributes.find_by(key: 'arkose_global_score').value).to eq('0')
      expect(user.custom_attributes.find_by(key: 'arkose_custom_score').value).to eq('0')
    end

    it 'executes abuse trust score workers' do
      expect(AntiAbuse::TrustScoreWorker).to receive(:perform_async).once.ordered.with(
        user.id, :arkose_global_score, 0.0
      )
      expect(AntiAbuse::TrustScoreWorker).to receive(:perform_async).once.ordered.with(
        user.id, :arkose_custom_score, 0.0
      )

      service.execute
    end

    it 'logs user risk band assignment event' do
      init_args = { session_token: nil, user: user, verify_response: response }
      expect_next_instance_of(::Arkose::Logger, init_args) do |logger|
        expect(logger).to receive(:log_risk_band_assignment)
      end

      service.execute
    end

    it 'returns a success response' do
      expect(service.execute).to be_success
    end

    it 'creates a Users::ArkoseSession for the user with relevant data' do
      expect { service.execute }.to change { user.arkose_sessions.count }.by(1)

      expect(user.arkose_sessions.last.session_xid).to eq(response.session_id)
    end

    context 'when response is from failed verification' do
      let(:arkose_verify_response) do
        Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/invalid_token.json')))
      end

      it 'does not add any custom attributes' do
        expect { service.execute }.not_to change { user.custom_attributes.count }
      end

      it 'does not store the arkose risk scores in abuse trust scores' do
        # Create and store initial scores
        create(:abuse_trust_score, user: user, score: 13.0, source: :arkose_global_score)
        create(:abuse_trust_score, user: user, score: 11.0, source: :arkose_custom_score)
        service.execute

        # Due to failed verification, there are no returned scores in arkose_verify_response,
        # we should expect `arkose_global_score` and `arkose_custom_score` not to be overwritten
        # and remain as the initial scores
        expect(user_scores.arkose_global_score).to eq(13.0)
        expect(user_scores.arkose_custom_score).to eq(11.0)
      end

      it 'does not create a Users::ArkoseSession for the user' do
        expect { service.execute }.not_to change { user.arkose_sessions.count }
      end

      it 'returns an error response' do
        expect(service.execute).to be_error
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns an error response' do
        expect(service.execute).to be_error
      end
    end
  end
end
