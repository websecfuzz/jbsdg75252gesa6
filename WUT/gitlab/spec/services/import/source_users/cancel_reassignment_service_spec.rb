# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::SourceUsers::CancelReassignmentService, feature_category: :importers do
  let(:user) { create(:user, :with_namespace) }
  let(:import_source_user) do
    create(:import_source_user, :awaiting_approval,
      reassign_to_user: user, reassigned_by_user: user, namespace: user.namespace
    )
  end

  let(:current_user) { user }
  let(:service) { described_class.new(import_source_user, current_user: current_user) }
  let(:result) { service.execute }

  describe '#execute' do
    context 'when cancelation is successful' do
      it 'returns success' do
        expect { result }
          .to trigger_internal_events('cancel_placeholder_user_reassignment')
          .with(
            namespace: import_source_user.namespace,
            user: current_user,
            additional_properties: {
              label: Gitlab::GlobalAnonymousId.user_id(import_source_user.placeholder_user),
              property: Gitlab::GlobalAnonymousId.user_id(user),
              import_type: import_source_user.import_type,
              reassign_to_user_state: user.state
            }
          )

        expect(result).to be_success
        expect(result.payload.reload).to eq(import_source_user)
        expect(result.payload.reassigned_by_user).to eq(nil)
        expect(result.payload.reassign_to_user).to eq(nil)
        expect(result.payload.pending_reassignment?).to eq(true)
      end
    end

    context 'when current user does not have permission' do
      let(:current_user) { create(:user) }

      it 'returns error no permissions' do
        expect(result).to be_error
        expect(result.message).to eq('You have insufficient permissions to update the import source user')
      end
    end

    context 'when import source user does not have a cancelable status' do
      before do
        allow(import_source_user).to receive(:cancelable_status?).and_return(false)
      end

      it 'returns error invalid status' do
        expect(result).to be_error
        expect(result.message).to eq('Import source user has an invalid status for this operation')
      end
    end

    context 'when an error occurs' do
      before do
        allow(import_source_user).to receive(:cancel_reassignment).and_return(false)
        allow(import_source_user).to receive(:errors).and_return(instance_double(ActiveModel::Errors,
          full_messages: ['Error']))
      end

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq(['Error'])
      end
    end
  end
end
