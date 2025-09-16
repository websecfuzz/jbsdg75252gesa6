# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::SecurityPolicyBotCleanupCronWorker, feature_category: :security_policy_management do
  let(:worker) { described_class.new }
  let_it_be(:admin_user) { create(:user, :admin_bot) }

  describe '#perform' do
    subject(:perform) { worker.perform }

    let(:expected_service_options) do
      {
        skip_authorization: true,
        hard_delete: false,
        reason_for_deletion: "Security policy bot no longer associated with any project"
      }
    end

    context 'with no security policy bots' do
      it 'does not delete any users' do
        expect_next_instance_of(Users::DestroyService) do |service|
          expect(service).not_to receive(:execute)
        end

        perform
      end
    end

    context 'with security policy bots that have project memberships' do
      let_it_be(:project) { create(:project) }
      let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

      before_all do
        create(:project_member, user: security_policy_bot, project: project)
      end

      it 'does not delete users with project memberships' do
        expect_next_instance_of(Users::DestroyService) do |service|
          expect(service).not_to receive(:execute)
        end

        perform
      end
    end

    context 'with security policy bots without project memberships' do
      let_it_be(:security_policy_bot_1) { create(:user, :security_policy_bot) }
      let_it_be(:security_policy_bot_2) { create(:user, :security_policy_bot) }
      let_it_be(:regular_user) { create(:user) }

      before do
        # We have to set MAX_BATCHES to 1 or use .and_call_original to make sure users get deleted.
        # However using .and_call_original will execute the service which modifies the options
        # resulting in a mismatch between expected_service_options and actual_options.
        stub_const('Users::SecurityPolicyBotCleanupCronWorker::MAX_BATCHES', 1)
      end

      it 'deletes security policy bots without project memberships' do
        expect_next_instance_of(Users::DestroyService) do |service|
          expect(service).to receive(:execute).with(security_policy_bot_1, expected_service_options)
          expect(service).to receive(:execute).with(security_policy_bot_2, expected_service_options)
        end

        perform
      end
    end

    context 'with mixed security policy bots' do
      let_it_be(:project) { create(:project) }
      let_it_be(:security_policy_bot_with_membership) { create(:user, :security_policy_bot) }
      let_it_be(:security_policy_bot_without_membership) { create(:user, :security_policy_bot) }

      before_all do
        create(:project_member, user: security_policy_bot_with_membership, project: project)
      end

      it 'only deletes security policy bots without project memberships' do
        expect_next_instance_of(Users::DestroyService) do |service|
          expect(service).to receive(:execute).with(security_policy_bot_without_membership,
            expected_service_options).and_call_original
        end

        perform
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(security_policy_bot_cleanup_cron_worker: false)
        end

        it 'does not delete users' do
          expect(Users::DestroyService).not_to receive(:new)

          perform
        end
      end
    end

    context 'with security policy bots and ghost user migrations' do
      let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }
      let_it_be(:ghost_security_policy_bot) { create(:user, :security_policy_bot) }
      let_it_be(:ghost_user_migration) { create(:ghost_user_migration, user: ghost_security_policy_bot) }

      it 'does not attempt to delete security policy bots with ghost user migration' do
        expect_next_instance_of(Users::DestroyService) do |service|
          expect(service).to receive(:execute).with(security_policy_bot, expected_service_options).and_call_original
        end

        perform
      end
    end

    context 'with number of security policy bots higher than the limit' do
      let_it_be(:security_policy_bots) { create_list(:user, 3, :security_policy_bot) }

      before do
        stub_const('Users::SecurityPolicyBotCleanupCronWorker::BATCH_SIZE', 2)
        stub_const('Users::SecurityPolicyBotCleanupCronWorker::MAX_BATCHES', 1)
      end

      it 'processes up to 2 users in a single execution' do
        expect_next_instance_of(Users::DestroyService) do |service|
          expect(service).to receive(:execute).twice
        end

        perform
      end
    end

    context 'when destroy raises an error' do
      let_it_be(:security_policy_bot_1) { create(:user, :security_policy_bot) }
      let_it_be(:security_policy_bot_2) { create(:user, :security_policy_bot) }

      before do
        allow_next_instance_of(Users::DestroyService) do |service|
          allow(service).to receive(:execute).and_call_original
          allow(service).to(
            receive(:execute)
              .with(security_policy_bot_1, expected_service_options)
              .and_raise(error_class, 'Service error')
          )
        end
      end

      shared_examples 'tracking error and continues processing' do
        it 'tracks the error and continues processing other users when one fails' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(instance_of(error_class), user_id: security_policy_bot_1.id).and_call_original

          expect { perform }.to change { security_policy_bot_2.reload.blocked? }.from(false).to(true)
        end

        context 'when processing multiple batches' do
          before do
            stub_const('Users::SecurityPolicyBotCleanupCronWorker::BATCH_SIZE', 1)
            stub_const('Users::SecurityPolicyBotCleanupCronWorker::MAX_BATCHES', 2)
          end

          it 'raises the error only once' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception)
              .with(instance_of(error_class), user_id: security_policy_bot_1.id).once.and_call_original

            expect { perform }.to change { security_policy_bot_2.reload.blocked? }.from(false).to(true)
          end
        end
      end

      context 'when AccessDeniedError is raised' do
        let(:error_class) { Gitlab::Access::AccessDeniedError }

        it_behaves_like 'tracking error and continues processing'
      end

      context 'when DestroyError is raised' do
        let(:error_class) { Users::DestroyService::DestroyError }

        it_behaves_like 'tracking error and continues processing'
      end
    end
  end
end
