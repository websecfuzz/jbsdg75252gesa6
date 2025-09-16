# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ReopenService, feature_category: :code_review_workflow do
  describe '#execute' do
    let_it_be(:merge_request) { create(:merge_request) }
    let_it_be(:project) { merge_request.target_project }

    let(:service_object) { described_class.new(project: project, current_user: merge_request.author) }

    subject(:merge_request_reopen_service) { service_object.execute(merge_request) }

    context 'for audit events' do
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }
      let_it_be(:merge_request) { create(:merge_request, author: project_bot) }

      include_examples 'audit event logging' do
        let(:operation) { merge_request_reopen_service }
        let(:event_type) { 'merge_request_reopened_by_project_bot' }
        let(:fail_condition!) { expect(project_bot).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: merge_request.target_project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: 'merge_request_reopened_by_project_bot',
              target_id: merge_request.id,
              target_type: 'MergeRequest',
              target_details: {
                iid: merge_request.iid,
                id: merge_request.id,
                source_branch: merge_request.source_branch,
                target_branch: merge_request.target_branch
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Reopened merge request #{merge_request.title}"
            }
          }
        end
      end
    end

    it 'publishes reopened event' do
      expect { merge_request_reopen_service }
        .to publish_event(::MergeRequests::ReopenedEvent).with(
          merge_request_id: merge_request.id
        )
    end

    context 'when the MR contains approvals' do
      let(:user) { create(:user) }
      let(:user2) { create(:user) }

      before do
        create(:approval, merge_request: merge_request, user: user)
        create(:approval, merge_request: merge_request, user: user2)
      end

      it 'deletes all the approvals' do
        expect { merge_request_reopen_service }.to change { merge_request.reload.approvals.size }
          .from(2).to(0)
      end
    end

    it_behaves_like 'audits security policy branch bypass' do
      let(:execute) { merge_request_reopen_service }
    end

    describe '#resync_policies' do
      let(:feature_licensed) { true }
      let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
      let_it_be(:project_approval_rule) do
        create(:approval_project_rule, :scan_finding, project: project, approvals_required: 1,
          scan_result_policy_read: scan_result_policy_read)
      end

      before do
        stub_licensed_features(security_orchestration_policies: feature_licensed)
      end

      it 'recreates policies violations based on approval rules' do
        expect { merge_request_reopen_service }
          .to change { merge_request.running_scan_result_policy_violations.count }.from(0).to(1)

        expect(merge_request.scan_result_policy_violations.first)
          .to have_attributes(
            project: project, merge_request: merge_request, scan_result_policy_read: scan_result_policy_read
          )
      end

      it 'triggers the policy synchronization' do
        expect(merge_request).to receive(:schedule_policy_synchronization)

        merge_request_reopen_service
      end

      it_behaves_like 'synchronizes policies for a merge request' do
        subject(:execute) { merge_request_reopen_service }
      end

      context 'when feature is not licensed' do
        let(:feature_licensed) { false }

        it 'does not trigger the synchronization' do
          expect(merge_request).not_to receive(:schedule_policy_synchronization)

          merge_request_reopen_service
        end

        it 'does not update the violations' do
          expect { merge_request_reopen_service }.not_to change { merge_request.scan_result_policy_violations.count }
        end
      end
    end
  end
end
