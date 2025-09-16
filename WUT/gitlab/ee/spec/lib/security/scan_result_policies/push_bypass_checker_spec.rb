# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PushBypassChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }

  let_it_be(:branch_name) { 'main' }
  let_it_be(:user) { create(:user, :project_bot) }
  let_it_be(:user_access) { Gitlab::UserAccess.new(user, container: project) }
  let_it_be(:checker) { described_class.new(project: project, user_access: user_access, branch_name: branch_name) }

  describe '#check_bypass!' do
    context 'when the feature is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'returns nil' do
        expect(checker.check_bypass!).to be_nil
      end
    end

    context 'when the feature is available' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when there are no policies with bypass settings' do
        it 'returns nil' do
          expect(checker.check_bypass!).to be_nil
        end
      end

      context 'when there is a policy with bypass settings for access token' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
        let_it_be_with_reload(:security_policy) do
          create(:security_policy, :approval_policy, linked_projects: [project],
            bypass_access_token_ids: [personal_access_token.id])
        end

        it 'returns true' do
          expect(checker.check_bypass!).to be true
        end

        context 'when the access token is not allowed to bypass' do
          before do
            another_access_token = create(:personal_access_token)
            security_policy.update!(content: { bypass_settings: { access_tokens: [{ id: another_access_token.id }] } })
          end

          it 'returns false' do
            expect(checker.check_bypass!).to be false
          end
        end
      end

      context 'with multiple security policies' do
        let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

        context 'when multiple policies have bypass_settings' do
          let_it_be_with_reload(:security_policy) do
            create(:security_policy, :approval_policy, linked_projects: [project],
              bypass_access_token_ids: [personal_access_token.id])
          end

          let_it_be_with_reload(:non_matching_security_policy) do
            create(:security_policy, :approval_policy, linked_projects: [project],
              bypass_access_token_ids: [999_999])
          end

          it 'returns true if any policy allows bypass' do
            expect(checker.check_bypass!).to be true
          end
        end

        context 'when only one policy has bypass_settings' do
          let_it_be_with_reload(:security_policy) do
            create(:security_policy, :approval_policy, linked_projects: [project],
              bypass_access_token_ids: [personal_access_token.id])
          end

          let_it_be_with_reload(:non_matching_security_policy) do
            create(:security_policy, :approval_policy, linked_projects: [project], content: {})
          end

          it 'returns true if the policy with bypass_settings allows bypass' do
            expect(checker.check_bypass!).to be true
          end
        end

        context 'when multiple policies have no bypass_settings' do
          let_it_be_with_reload(:security_policy1) do
            create(:security_policy, :approval_policy, linked_projects: [project], content: {})
          end

          let_it_be_with_reload(:security_policy2) do
            create(:security_policy, :approval_policy, linked_projects: [project], content: {})
          end

          it 'returns nil' do
            expect(checker.check_bypass!).to be_nil
          end
        end
      end
    end
  end
end
