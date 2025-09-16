# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PolicyBypassChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:branch_name) { 'main' }
  let_it_be(:user) { create(:user, :project_bot) }
  let_it_be(:service_account) { create(:service_account) }

  let_it_be_with_refind(:security_policy) do
    create(:security_policy, linked_projects: [project], content: { bypass_settings: {} })
  end

  let_it_be(:service_account_access) { Gitlab::UserAccess.new(service_account, container: project) }
  let_it_be(:user_access) { Gitlab::UserAccess.new(user, container: project) }

  describe '#bypass_allowed?' do
    subject(:bypass_allowed?) do
      described_class.new(
        security_policy: security_policy, project: project, user_access: user_access, branch_name: branch_name
      ).bypass_allowed?
    end

    before do
      allow(Gitlab::Audit::Auditor).to receive(:audit).and_call_original
    end

    shared_examples 'bypass is not allowed and audit log is not created' do
      it 'returns false and does not create an audit log' do
        result = bypass_allowed?

        expect(result).to be false
        expect(Gitlab::Audit::Auditor).not_to have_received(:audit).with(
          hash_including(message: a_string_including("Blocked branch push is bypassed by security policy"))
        )
      end
    end

    context 'when bypass_settings is blank' do
      before do
        security_policy.update!(content: { actions: [] })
      end

      it_behaves_like 'bypass is not allowed and audit log is not created'
    end

    context 'when bypass_settings has access_tokens' do
      let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

      before do
        security_policy.update!(content: { bypass_settings: { access_tokens: [{ id: personal_access_token.id }] } })
      end

      context 'when the access token is inactive' do
        before do
          personal_access_token.update!(expires_at: 1.day.ago)
        end

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end

      context 'when the access token is active' do
        before do
          personal_access_token.update!(expires_at: nil)
        end

        it 'returns true and creates an audit log' do
          result = bypass_allowed?

          expect(result).to be true
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(hash_including(
            name: 'security_policy_access_token_push_bypass',
            author: user,
            scope: project,
            target: security_policy,
            message: a_string_including("Blocked branch push is bypassed by security policy"),
            additional_details: hash_including(
              security_policy_name: security_policy.name,
              security_policy_id: security_policy.id,
              branch_name: branch_name
            )
          ))
        end
      end

      context 'when the access token is not allowed to bypass' do
        before do
          another_access_token = create(:personal_access_token)
          security_policy.update!(content: { bypass_settings: { access_tokens: [{ id: another_access_token.id }] } })
        end

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end

      context 'when user_access is not a project bot' do
        let_it_be(:user_access) do
          normal_user = create(:user)
          Gitlab::UserAccess.new(normal_user, container: project)
        end

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end
    end

    context 'when bypass_settings has service_accounts' do
      before do
        security_policy.update!(content: { bypass_settings: { service_accounts: [{ id: service_account.id }] } })
      end

      context 'when user_access is the allowed service account' do
        let_it_be(:user_access) { service_account_access }

        it 'returns true and creates an audit log' do
          result = bypass_allowed?

          expect(result).to be true
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(hash_including(
            name: 'security_policy_service_account_push_bypass',
            author: service_account,
            scope: project,
            target: security_policy,
            message: a_string_including("Blocked branch push is bypassed by security policy"),
            additional_details: hash_including(
              security_policy_name: security_policy.name,
              security_policy_id: security_policy.id,
              branch_name: branch_name
            )
          ))
        end
      end

      context 'when user_access is a different service account' do
        let_it_be(:user_access) do
          other_service_account = create(:service_account)
          Gitlab::UserAccess.new(other_service_account, container: project)
        end

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end

      context 'when user_access is not a service account' do
        let_it_be(:user_access) { Gitlab::UserAccess.new(user, container: project) }

        it_behaves_like 'bypass is not allowed and audit log is not created'
      end
    end
  end
end
