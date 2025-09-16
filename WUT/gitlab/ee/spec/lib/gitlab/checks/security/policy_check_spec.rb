# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::Security::PolicyCheck, '#validate!', feature_category: :security_policy_management do
  include RepoHelpers

  include_context 'change access checks context'

  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be_with_refind(:policy_project) { create(:project, :repository) }
  let_it_be_with_refind(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      project: project,
      security_policy_management_project: policy_project)
  end

  let!(:protected_branch) { project.protected_branches.create!(name: branch_name) }
  let(:force_push?) { true }
  let(:branch_name) { 'master' }

  subject(:policy_check!) { described_class.new(change_access).validate! }

  before do
    allow(Gitlab::Checks::ForcePush).to receive(:force_push?).with(project, oldrev, newrev).and_return(force_push?)

    stub_licensed_features(security_orchestration_policies: true)
  end

  context 'when unaffected by active scan result policy' do
    before do
      policy_configuration.delete
    end

    it 'does not raise' do
      expect { policy_check! }.not_to raise_error
    end
  end

  context 'when affected by active scan result policy' do
    include_context 'with approval policy preventing force pushing'

    it 'raises' do
      expect do
        policy_check!
      end.to raise_error(Gitlab::GitAccess::ForbiddenError, described_class::FORCE_PUSH_ERROR_MESSAGE)
    end

    context 'when prevent_pushing_and_force_pushing setting is disabled' do
      let(:prevent_pushing_and_force_pushing) { false }

      it 'does not raise' do
        expect { policy_check! }.not_to raise_error
      end
    end

    context 'when branch is unprotected' do
      let!(:protected_branch) { nil }

      it 'does not raise' do
        expect { policy_check! }.not_to raise_error
      end
    end

    context 'when push is not forced' do
      let(:force_push?) { false }

      context 'when there is a matching MR' do
        before do
          allow_next_instance_of(Gitlab::Checks::MatchingMergeRequest) do |instance|
            allow(instance).to receive(:match?).and_return(true)
          end
        end

        it 'does not raise' do
          expect { policy_check! }.not_to raise_error
        end
      end

      context 'when there is no matching MR' do
        before do
          allow_next_instance_of(Gitlab::Checks::MatchingMergeRequest) do |instance|
            allow(instance).to receive(:match?).and_return(false)
          end
        end

        it 'raises error' do
          expect do
            policy_check!
          end.to raise_error(Gitlab::GitAccess::ForbiddenError, described_class::PUSH_ERROR_MESSAGE)
        end
      end
    end

    context 'with licensed feature unavailable' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'does not raise' do
        expect { policy_check! }.not_to raise_error
      end
    end

    context 'with bypass_settings' do
      let_it_be(:user) { create(:user, :project_bot) }
      let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

      context 'when policies_bypass_applied? allows bypass with access token' do
        before do
          create(:security_policy, linked_projects: [project], bypass_access_token_ids: [personal_access_token.id])
        end

        it 'does not raise' do
          expect { policy_check! }.not_to raise_error
        end
      end

      context 'when policies_bypass_applied? does not allow bypass with access token' do
        before do
          # Create a policy with a different access token, so the current token is not allowed
          another_token = create(:personal_access_token)
          create(:security_policy, linked_projects: [project], bypass_access_token_ids: [another_token.id])
        end

        it 'raises error' do
          expect { policy_check! }.to raise_error(
            Gitlab::GitAccess::ForbiddenError, described_class::FORCE_PUSH_ERROR_MESSAGE
          )
        end
      end
    end

    context 'when the security_policies_bypass_options_tokens_accounts feature flag is disabled' do
      before do
        stub_feature_flags(security_policies_bypass_options_tokens_accounts: false)
      end

      it 'does not bypass and raises error' do
        expect { policy_check! }.to raise_error(
          Gitlab::GitAccess::ForbiddenError, described_class::FORCE_PUSH_ERROR_MESSAGE
        )
      end
    end
  end
end
