# frozen_string_literal: true

require 'spec_helper'

using RSpec::Parameterized::TableSyntax

RSpec.describe Ai::DuoWorkflow, feature_category: :ai_abstraction_layer do
  let_it_be(:current_user) { create(:user, :admin) }
  let_it_be_with_reload(:service_account_user) { create(:user, :service_account) }
  let_it_be_with_reload(:doorkeeper_application) { create(:doorkeeper_application) }

  describe '#enabled?' do
    where(:duo_workflow_license_available, :duo_enabled, :result) do
      true  | false | false
      false | false | false
      false | true  | false
      true  | true  | true
    end

    with_them do
      before do
        stub_licensed_features(ai_workflows: duo_workflow_license_available)
        stub_ee_application_setting(duo_features_enabled: duo_enabled)
      end

      it 'returns the expected result' do
        expect(described_class.enabled?).to eq(result)
      end
    end
  end

  describe '#connected?' do
    context 'when duo workflow is not enabled' do
      before do
        allow(described_class).to receive(:enabled?).and_return(false)
      end

      it 'returns not connected' do
        expect(described_class.connected?).to be(false)
      end
    end

    context 'when duo workflow is enabled' do
      where(:service_account, :oauth_app, :result) do
        nil                         | nil                           | false
        ref(:service_account_user)  | nil                           | false
        nil                         | ref(:doorkeeper_application)  | false
        ref(:service_account_user)  | ref(:doorkeeper_application)  | true
      end

      with_them do
        before do
          allow(described_class).to receive(:enabled?).and_return(true)
          Ai::Setting.instance.update!(duo_workflow_service_account_user: service_account,
            duo_workflow_oauth_application: oauth_app)
        end

        it 'returns the expected result' do
          expect(described_class.connected?).to be result
        end
      end
    end
  end

  describe '#available?' do
    shared_examples 'returns not available' do
      it 'returns not available' do
        expect(described_class.available?).to be(false)
      end
    end

    shared_examples 'returns available' do
      it 'returns available' do
        expect(described_class.available?).to be(true)
      end
    end

    context 'when duo workflow is not connected' do
      before do
        allow(described_class).to receive(:connected?).and_return(false)
      end

      it_behaves_like 'returns not available'
    end

    context 'when duo workflow is connected' do
      before do
        allow(described_class).to receive(:connected?).and_return(true)
        Ai::Setting.instance.update!(
          duo_workflow_service_account_user: service_account_user,
          duo_workflow_oauth_application: doorkeeper_application
        )
      end

      context 'with invalid configurations' do
        context 'when service account is blocked' do
          before do
            service_account_user.block
          end

          after do
            service_account_user.activate
          end

          it_behaves_like 'returns not available'
        end

        context 'when service account does not have composite identity enforced' do
          before do
            service_account_user.composite_identity_enforced = false
          end

          after do
            service_account_user.composite_identity_enforced = true
          end

          it_behaves_like 'returns not available'
        end

        context 'when oauth_app does not have dynamic user scope' do
          it_behaves_like 'returns not available'
        end
      end

      context 'with valid configuration' do
        context 'when oauth_app has dynamic user scope' do
          before do
            allow(described_class).to receive(:connected?).and_return(true)
            doorkeeper_application.update!(scopes: [::Gitlab::Auth::DYNAMIC_USER])
            service_account_user.update!(composite_identity_enforced: true)
          end

          it_behaves_like 'returns available'
        end
      end
    end
  end

  describe '#ensure_service_account_blocked!' do
    let_it_be(:current_user) { create(:user, :admin) }
    let_it_be_with_reload(:blocked_service_account) { create(:user, :service_account, :blocked) }
    let_it_be(:service_account_not_found) { Struct.new(:id).new(999999) }

    context 'with service_account set in application settings' do
      where(:service_account, :expected_service_class, :expected_status, :expected_message) do
        ref(:service_account_user) | ::Users::BlockService | true | nil
        ref(:blocked_service_account) | nil | true | "Service account already blocked. Nothing to do."
      end

      with_them do
        before do
          Ai::Setting.instance.update!(duo_workflow_service_account_user_id: service_account&.id)
        end

        it 'conditionally block the service account', :aggregate_failures do
          if expected_service_class
            expect_next_instance_of(expected_service_class, current_user) do |instance|
              expect(instance).to receive(:execute).with(service_account).and_call_original
            end
          end

          response = described_class.ensure_service_account_blocked!(current_user: current_user)

          expect(response.success?).to be(expected_status)
          expect(response.message).to be(expected_message)
        end
      end
    end

    context 'with service_account set as argument' do
      it 'conditionally blocks the given service account', :aggregate_failures do
        expect(service_account_user.blocked?).to be(false)

        response = described_class.ensure_service_account_blocked!(
          current_user: current_user,
          service_account: service_account_user
        )

        expect(response.success?).to be(true)
        expect(service_account_user.blocked?).to be(true)
      end
    end
  end

  describe '#ensure_service_account_unblocked!' do
    let_it_be(:current_user) { create(:user, :admin) }
    let_it_be_with_reload(:blocked_service_account) { create(:user, :service_account, :blocked) }

    context 'with service_account set in application settings' do
      where(:service_account, :expected_service_class, :expected_status, :expected_message) do
        ref(:service_account_user) | nil | true | "Service account already unblocked. Nothing to do."
        ref(:blocked_service_account) | ::Users::UnblockService | true | nil
      end

      with_them do
        before do
          Ai::Setting.instance.update!(duo_workflow_service_account_user_id: service_account&.id)
        end

        it 'conditionally block the service account', :aggregate_failures do
          if expected_service_class
            expect_next_instance_of(expected_service_class, current_user) do |instance|
              expect(instance).to receive(:execute).with(service_account).and_call_original
            end
          end

          response = described_class.ensure_service_account_unblocked!(current_user: current_user)

          expect(response.success?).to be(expected_status)
          expect(response.message).to be(expected_message)
        end
      end
    end

    context 'with service_account set as argument' do
      it 'conditionally blocks the given service account', :aggregate_failures do
        expect(blocked_service_account.blocked?).to be(true)

        response = described_class.ensure_service_account_unblocked!(
          current_user: current_user,
          service_account: blocked_service_account
        )

        expect(response.success?).to be(true)
        expect(blocked_service_account.blocked?).to be(false)
      end
    end
  end
end
