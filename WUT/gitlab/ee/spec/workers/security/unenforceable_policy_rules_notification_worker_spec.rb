# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::UnenforceablePolicyRulesNotificationWorker, feature_category: :security_policy_management do
  let_it_be(:merge_request) { create(:ee_merge_request) }
  let_it_be(:project) { merge_request.project }
  let(:feature_licensed) { true }
  let(:params) { {} }
  let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
  let!(:approval_rule) do
    create(:report_approver_rule, :scan_finding, merge_request: merge_request,
      scan_result_policy_read: scan_result_policy_read)
  end

  before do
    stub_licensed_features(security_orchestration_policies: feature_licensed)
  end

  describe '#perform' do
    subject(:run_worker) { described_class.new.perform(merge_request_id, params) }

    let(:merge_request_id) { merge_request.id }

    it 'calls UnenforceablePolicyRulesNotificationService' do
      expect_next_instance_of(Security::UnenforceablePolicyRulesNotificationService, merge_request) do |instance|
        expect(instance).to receive(:execute)
      end

      run_worker
    end

    context 'when there is no approval rule with scan result policy read' do
      let(:approval_rule) { nil }

      it 'does not call UnenforceablePolicyRulesNotificationService' do
        expect(Security::UnenforceablePolicyRulesNotificationService).not_to receive(:new)

        run_worker
      end

      context 'when force_without_approval_rules param is provided' do
        let(:params) { { 'force_without_approval_rules' => true } }

        it 'calls UnenforceablePolicyRulesNotificationService' do
          expect_next_instance_of(Security::UnenforceablePolicyRulesNotificationService, merge_request) do |instance|
            expect(instance).to receive(:execute)
          end

          run_worker
        end
      end
    end

    context 'when merge_request does not exist' do
      let(:merge_request_id) { non_existing_record_id }

      it 'does not call UnenforceablePolicyRulesNotificationService' do
        expect(Security::UnenforceablePolicyRulesNotificationService).not_to receive(:new)

        run_worker
      end
    end

    context 'when feature is not licensed' do
      let(:feature_licensed) { false }

      it 'does not call UnenforceablePolicyRulesNotificationService' do
        expect(Security::UnenforceablePolicyRulesNotificationService).not_to receive(:new)

        run_worker
      end
    end
  end
end
