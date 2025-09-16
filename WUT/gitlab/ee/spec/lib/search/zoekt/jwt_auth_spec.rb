# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::JwtAuth, feature_category: :global_search do
  describe '.secret_token' do
    it 'returns the GitLab shell secret token' do
      expect(Gitlab::Shell).to receive(:secret_token).and_return('test-secret-token')
      expect(described_class.secret_token).to eq('test-secret-token')
    end
  end

  describe '.jwt_token' do
    it 'generates a JWT token with the expected claims', :freeze_time do
      secret = 'test-secret'
      allow(described_class).to receive(:secret_token).and_return(secret)

      token = described_class.jwt_token
      decoded_token = JWT.decode(token, secret, true, { algorithm: 'HS256' })[0]
      current_time = Time.current.to_i

      expect(decoded_token).to include(
        'iss' => described_class::ISSUER,
        'aud' => described_class::AUDIENCE,
        'iat' => current_time,
        'exp' => current_time + described_class::TOKEN_EXPIRE_TIME.to_i
      )
    end
  end

  describe '.authorization_header' do
    it 'returns the Authorization header value with Bearer scheme' do
      expect(described_class).to receive(:jwt_token).and_return('test-token')
      expect(described_class.authorization_header).to eq('Bearer test-token')
    end
  end
end
