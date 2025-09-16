# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::RestoreService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) do
    create(:group_with_deletion_schedule,
      marked_for_deletion_on: 1.day.ago,
      deleting_user: user,
      owners: user)
  end

  subject(:execute) { described_class.new(group, user, {}).execute }

  context 'for audit events' do
    it 'logs audit event', :aggregate_failures do
      allow(::Gitlab::Audit::Auditor).to receive(:audit).and_call_original
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'group_restored')
      ).and_call_original

      expect { execute }.to change { AuditEvent.count }.by(1)
    end
  end
end
