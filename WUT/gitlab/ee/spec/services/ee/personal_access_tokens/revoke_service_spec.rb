# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::RevokeService, feature_category: :system_access do
  before do
    stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
  end

  let_it_be(:source) { nil }
  let_it_be(:expected_source) { :self }

  describe '#execute' do
    subject(:revoke_token) { service.execute }

    before do
      allow(::Gitlab::Audit::Auditor).to receive(:audit).and_call_original
    end

    let(:service) { described_class.new(current_user, token: token, group: group, source: source) }

    shared_examples_for 'a successfully revoked token' do
      before do
        revoke_token
      end

      it { expect(revoke_token.success?).to be true }
      it { expect(service.token.revoked?).to be true }

      it do
        expect(::Gitlab::Audit::Auditor).to have_received(:audit)
          .with(hash_including(
            name: 'personal_access_token_revoked',
            message: "Revoked personal access token with id #{token.id}",
            additional_details: { revocation_source: expected_source, event_name: "personal_access_token_revoked" }
          ))
      end
    end

    shared_examples_for 'an unsuccessfully revoked token' do
      it { expect(revoke_token.success?).to be false }
      it { expect(service.token.revoked?).to be false }

      it do
        revoke_token
        expect(::Gitlab::Audit::Auditor).to have_received(:audit)
          .with(hash_including(
            name: 'personal_access_token_revoked',
            message: start_with("Attempted to revoke personal access token with id #{token.id}"),
            additional_details: { revocation_source: expected_source, event_name: "personal_access_token_revoked" }
          ))
      end
    end

    context 'when source is not self' do
      let_it_be(:token) { create(:personal_access_token) }
      let_it_be(:current_user) { token.user }
      let_it_be(:source) { :secret_detection }
      let_it_be(:expected_source) { :secret_detection }
      let(:service) { described_class.new(current_user, token: token, source: source) }

      it_behaves_like 'a successfully revoked token'
    end

    context 'when revoking a managed service account token' do
      let(:provisioned_by_group) { create(:group) }
      let(:service_account_user) { create(:user, :service_account, provisioned_by_group: provisioned_by_group) }
      let(:token) { create(:personal_access_token, user: service_account_user) }
      let(:current_user) { create(:user) }
      let(:group) { provisioned_by_group }

      context 'when current user can admin service accounts for the provisioning group' do
        before do
          stub_licensed_features(service_accounts: true)
          provisioned_by_group.add_owner(current_user)
        end

        it_behaves_like 'a successfully revoked token'
      end

      context 'when current user cannot admin service accounts for the provisioning group' do
        it_behaves_like 'an unsuccessfully revoked token'
      end
    end
  end
end
