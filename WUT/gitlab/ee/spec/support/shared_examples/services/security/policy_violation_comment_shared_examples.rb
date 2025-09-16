# frozen_string_literal: true

RSpec.shared_examples_for 'triggers policy bot comment' do |expected_violation|
  it 'enqueues Security::GeneratePolicyViolationCommentWorker' do
    expect(Security::GeneratePolicyViolationCommentWorker).to receive(:perform_async).with(merge_request.id)

    execute
  end

  context 'when some violations are not populated' do
    let_it_be(:other_scan_result_policy_read) { create(:scan_result_policy_read, project: merge_request.project) }

    before do
      create(:scan_result_policy_violation, scan_result_policy_read: other_scan_result_policy_read,
        merge_request: merge_request, project: merge_request.project, violation_data: nil)
    end

    it_behaves_like 'does not trigger policy bot comment'
  end

  if expected_violation
    context 'when bot comment is disabled' do
      context 'when it is disabled for all policies' do
        before do
          merge_request.project.scan_result_policy_reads.update_all(send_bot_message: { enabled: false })
        end

        it_behaves_like 'does not trigger policy bot comment'
      end

      context 'when it is disabled only for one policy' do
        before do
          policy = create(:scan_result_policy_read, :with_send_bot_message, project: merge_request.project,
            bot_message_enabled: false)
          create(:report_approver_rule, :scan_finding, merge_request: merge_request, scan_result_policy_read: policy,
            name: 'Rule with disabled policy bot comment')
        end

        it 'enqueues Security::GeneratePolicyViolationCommentWorker' do
          expect(Security::GeneratePolicyViolationCommentWorker).to receive(:perform_async).with(merge_request.id)

          execute
        end
      end

      context 'when it is disabled for a violated policy and enabled for an unviolated policy' do
        before do
          # Disable for all policies, including the violated ones
          merge_request.project.scan_result_policy_reads.update_all(send_bot_message: { enabled: false })
          # Create a rule without violations for unviolated policy with enabled policy bot comment
          policy = create(:scan_result_policy_read, :with_send_bot_message, project: merge_request.project)
          create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
            scan_result_policy_read: policy, name: 'Unviolated rule with enabled policy bot comment')
        end

        it_behaves_like 'does not trigger policy bot comment'

        context 'when a comment is already present on the merge request' do
          include Security::PolicyBotCommentHelpers

          before do
            create_policy_bot_comment(merge_request)
          end

          it 'enqueues Security::GeneratePolicyViolationCommentWorker' do
            expect(Security::GeneratePolicyViolationCommentWorker).to receive(:perform_async).with(merge_request.id)

            execute
          end
        end
      end
    end
  end
end

RSpec.shared_examples_for "does not trigger policy bot comment" do
  it 'does not trigger policy bot comment' do
    expect(Security::GeneratePolicyViolationCommentWorker).not_to receive(:perform_async)

    execute
  end
end

RSpec.shared_examples_for 'does not trigger policy bot comment for archived project' do
  before do
    archived_project.update!(archived: true)
  end

  it_behaves_like 'does not trigger policy bot comment'
end
