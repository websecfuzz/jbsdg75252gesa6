# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'audits security policy branch bypass' do
  let_it_be_with_refind(:merge_request) do
    create(:merge_request, source_branch: 'feature', target_branch: 'main')
  end

  context 'when security policy with branch bypass is present' do
    let_it_be(:security_policy) do
      create(:security_policy, content: {
        bypass_settings: {
          branches: [
            { source: { name: 'feature' }, target: { name: 'main' } }
          ]
        }
      })
    end

    let_it_be(:approval_policy_rule) do
      create(:approval_policy_rule, security_policy: security_policy)
    end

    let_it_be(:approval_rule) do
      create(:approval_merge_request_rule, merge_request: merge_request, approval_policy_rule: approval_policy_rule)
    end

    it 'creates an audit event' do
      expect { execute }.to change { AuditEvent.count }.by(1)

      event = AuditEvent.last
      expect(event.details[:custom_message]).to include('Approvals bypassed by security policy')
      expect(event.entity).to eq(merge_request.target_project)
    end

    context 'when approval_policy_branch_exceptions is disabled' do
      before do
        stub_feature_flags(approval_policy_branch_exceptions: false)
      end

      it 'does not create an audit event' do
        expect { execute }.not_to change { AuditEvent.count }
      end
    end
  end

  context 'when security policy does not exist with branch bypass' do
    it 'does not create an audit event' do
      expect { execute }.not_to change { AuditEvent.count }
    end
  end
end
