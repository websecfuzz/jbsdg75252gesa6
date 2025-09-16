# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ResetApprovalsService, feature_category: :code_review_workflow do
  let_it_be(:current_user) { create(:user) }

  let(:service) { described_class.new(project: project, current_user: current_user) }
  let(:group) { create(:group) }
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository, namespace: group, approvals_before_merge: 1, reset_approvals_on_push: true) }

  let(:merge_request) do
    create(:merge_request,
      author: current_user,
      source_project: project,
      source_branch: 'master',
      target_branch: 'feature',
      target_project: project,
      merge_when_pipeline_succeeds: true,
      merge_user: user,
      reviewers: [owner])
  end

  let(:commits) { merge_request.commits }
  let(:oldrev) { commits.last.id }
  let(:newrev) { commits.first.id }
  let(:owner) { create(:user, username: 'co1') }
  let(:approver) { create(:user, username: 'co2') }
  let(:security) { create(:user) }
  let(:notification_service) { spy('notification_service') }

  def approval_todos(merge_request)
    Todo.where(action: Todo::APPROVAL_REQUIRED, target: merge_request)
  end

  describe "#execute" do
    before do
      stub_licensed_features(multiple_approval_rules: true)
      allow(service).to receive(:execute_hooks)
      allow(NotificationService).to receive(:new) { notification_service }
      project.add_developer(approver)
      project.add_developer(owner)
    end

    shared_examples_for 'MergeRequests::ApprovalsResetEvent published' do
      it 'publishes MergeRequests::ApprovalsResetEvent' do
        expect { action }
          .to publish_event(MergeRequests::ApprovalsResetEvent)
          .with(expected_data)
      end
    end

    shared_examples_for 'MergeRequests::ApprovalsResetEvent not published' do
      it 'does not publish MergeRequests::ApprovalsResetEvent' do
        expect { action }
          .not_to publish_event(MergeRequests::ApprovalsResetEvent)
      end
    end

    shared_examples_for "Executing automerge process worker" do
      context 'when auto merge is enabled' do
        it 'calls automerge process worker' do
          expect(AutoMergeProcessWorker).to receive(:perform_async).with(merge_request.id)

          action
        end
      end

      context 'when auto merge is not enabled' do
        let(:merge_request) do
          create(:merge_request,
            author: current_user,
            source_project: project,
            source_branch: 'master',
            target_branch: 'feature',
            target_project: project,
            merge_user: user,
            reviewers: [owner])
        end

        it 'does not call automerge process worker' do
          expect(AutoMergeProcessWorker).not_to receive(:perform_async)

          action
        end
      end
    end

    context 'as default' do
      let(:patch_id_sha) { nil }

      let!(:approval_1) do
        create(
          :approval,
          merge_request: merge_request,
          user: approver,
          patch_id_sha: patch_id_sha
        )
      end

      let!(:approval_2) do
        create(
          :approval,
          merge_request: merge_request,
          user: owner,
          patch_id_sha: patch_id_sha
        )
      end

      before do
        perform_enqueued_jobs do
          merge_request.update!(approver_ids: [approver.id, owner.id, current_user.id])
        end
      end

      it 'updates reviewers state' do
        expect { service.execute('refs/heads/master', newrev) }.to change { merge_request.merge_request_reviewers.first.state }.from("unreviewed").to("unapproved")
      end

      it 'resets all approvals and does not create new todos for approvers' do
        service.execute('refs/heads/master', newrev)
        merge_request.reload

        expect(merge_request.approvals).to be_empty
        expect(approval_todos(merge_request).map(&:user)).to be_empty
      end

      it 'removes the unmergeable flag after the service is run' do
        merge_request.approval_state.temporarily_unapprove!

        service.execute('refs/heads/master', newrev)
        merge_request.reload

        expect(merge_request.approval_state.temporarily_unapproved?).to be_falsey
      end

      it_behaves_like 'Executing automerge process worker' do
        let(:action) { service.execute('refs/heads/master', newrev) }
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { service.execute('refs/heads/master', newrev) }
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { service.execute('refs/heads/master', newrev) }
      end

      it_behaves_like 'MergeRequests::ApprovalsResetEvent published' do
        let(:action) { service.execute('refs/heads/master', newrev) }

        let(:expected_data) do
          {
            current_user_id: current_user.id,
            merge_request_id: merge_request.id,
            cause: 'new_push',
            approver_ids: merge_request.approvals.pluck(:user_id)
          }
        end
      end

      context 'when approvals patch_id_sha matches MergeRequest#current_patch_id_sha' do
        let(:patch_id_sha) { merge_request.current_patch_id_sha }

        it 'does not delete approvals' do
          service.execute('refs/heads/master', newrev)

          merge_request.reload

          expect(merge_request.approvals).to contain_exactly(approval_1, approval_2)
        end

        it_behaves_like 'MergeRequests::ApprovalsResetEvent not published' do
          let(:action) { service.execute('refs/heads/master', newrev) }
        end
      end
    end

    context 'when skip_reset_checks: true' do
      let(:patch_id_sha) { nil }

      let!(:approval_1) do
        create(
          :approval,
          merge_request: merge_request,
          user: approver,
          patch_id_sha: patch_id_sha
        )
      end

      let!(:approval_2) do
        create(
          :approval,
          merge_request: merge_request,
          user: owner,
          patch_id_sha: patch_id_sha
        )
      end

      before do
        perform_enqueued_jobs do
          merge_request.update!(approver_ids: [approver.id, owner.id, current_user.id])
        end
      end

      it 'deletes all approvals directly without additional checks or side-effects' do
        expect(service).to receive(:delete_approvals).and_call_original
        expect(service).not_to receive(:reset_approvals)

        service.execute('refs/heads/master', newrev, skip_reset_checks: true)

        merge_request.reload

        expect(merge_request.approvals).to be_empty
        expect(approval_todos(merge_request)).to be_empty
      end

      it 'will delete approvals in situations where a false setting would not' do
        expect(service).to receive(:reset_approvals?).and_return(false)

        expect do
          service.execute('refs/heads/master', newrev)
          merge_request.reload
        end.not_to change { merge_request.approvals.length }

        allow(service).to receive(:reset_approvals?).and_call_original
        expect(service).to receive(:delete_approvals).and_call_original
        expect(service).not_to receive(:reset_approvals)

        service.execute('refs/heads/master', newrev, skip_reset_checks: true)

        merge_request.reload

        expect(merge_request.approvals).to be_empty
        expect(approval_todos(merge_request)).to be_empty
      end

      it_behaves_like 'Executing automerge process worker' do
        let(:action) { service.execute('refs/heads/master', newrev, skip_reset_checks: true) }
      end

      it_behaves_like 'MergeRequests::ApprovalsResetEvent published' do
        let(:action) { service.execute('refs/heads/master', newrev, skip_reset_checks: true) }

        let(:expected_data) do
          {
            current_user_id: current_user.id,
            merge_request_id: merge_request.id,
            cause: 'new_push',
            approver_ids: merge_request.approvals.pluck(:user_id)
          }
        end
      end

      context 'when approvals patch_id_sha matches MergeRequest#current_patch_id_sha' do
        let(:patch_id_sha) { merge_request.current_patch_id_sha }

        it 'does not delete approvals' do
          service.execute('refs/heads/master', newrev, skip_reset_checks: true)

          merge_request.reload

          expect(merge_request.approvals).to contain_exactly(approval_1, approval_2)
        end

        it_behaves_like 'MergeRequests::ApprovalsResetEvent not published' do
          let(:action) { service.execute('refs/heads/master', newrev, skip_reset_checks: true) }
        end
      end
    end

    context 'with selective code owner removals' do
      let_it_be(:project) do
        create(:project,
          :repository,
          reset_approvals_on_push: false,
          project_setting_attributes: { selective_code_owner_removals: true }
        )
      end

      let_it_be(:codeowner) do
        project.repository.create_file(
          current_user,
          'CODEOWNERS',
          "*.rb @co1\n*.js @co2",
          message: 'Add CODEOWNERS',
          branch_name: 'master'
        )
      end

      let_it_be(:feature_sha1) do
        project.repository.create_file(
          current_user,
          'another.rb',
          '2',
          message: '2',
          branch_name: 'feature'
        )
      end

      let_it_be(:feature_sha2) do
        project.repository.create_file(
          current_user,
          'some.js',
          '3',
          message: '3',
          branch_name: 'feature'
        )
      end

      let_it_be(:feature_sha3) do
        project.repository.create_file(
          current_user,
          'last.rb',
          '4',
          message: '4',
          branch_name: 'feature'
        )
      end

      let_it_be(:feature2_change_unrelated_to_codeowners) do
        project.repository.add_branch(current_user, 'feature2', 'feature')
        project.repository.create_file(
          current_user,
          'file.txt',
          'text',
          message: 'text file',
          branch_name: 'feature2'
        )
      end

      let(:patch_id_sha) { previous_merge_request_diff.patch_id_sha }

      let(:security_approval) do
        create(
          :approval,
          merge_request: merge_request,
          user: security,
          patch_id_sha: patch_id_sha
        )
      end

      let(:js_approval) do
        create(
          :approval,
          merge_request: merge_request,
          user: approver,
          patch_id_sha: patch_id_sha
        )
      end

      let(:rb_approval) do
        create(
          :approval,
          merge_request: merge_request,
          user: owner,
          patch_id_sha: patch_id_sha
        )
      end

      let!(:previous_merge_request_diff) do
        create(:merge_request_diff,
          merge_request: merge_request,
          head_commit_sha: feature_sha2,
          start_commit_sha: merge_request.target_branch_sha,
          base_commit_sha: merge_request.target_branch_sha
        )
      end

      let!(:merge_request) do
        create(:merge_request,
          # Skip creating the diff so we can specify them for the context
          :skip_diff_creation,
          author: current_user,
          source_project: project,
          source_branch: 'feature',
          target_project: project,
          target_branch: 'master',
          reviewers: [owner]
        )
      end

      before do
        perform_enqueued_jobs do
          merge_request.update!(approver_ids: [approver.id, owner.id, current_user.id])
        end
        create(:any_approver_rule, merge_request: merge_request, users: [approver, owner, security])

        merge_request.approval_rules.regular.each do |rule|
          rule.users = [security]
        end

        previous_merge_request_diff
        merge_request.create_merge_request_diff

        # Instantiate these after the MergeRequestDiff we will use for patch_id_sha
        security_approval
        js_approval
        rb_approval
        ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute
      end

      it 'updates reviewers state' do
        expect { service.execute('feature', feature_sha3) }.to change { merge_request.merge_request_reviewers.first.state }.from("unreviewed").to("unapproved")
      end

      context 'when the latest push is related to codeowners' do
        it 'resets code owner approvals with changes' do
          service.execute('feature', feature_sha3)
          merge_request.reload

          expect(merge_request.approvals.count).to eq(2)
          expect(merge_request.approvals).to contain_exactly(security_approval, js_approval)
        end

        it_behaves_like 'MergeRequests::ApprovalsResetEvent published' do
          let(:action) { service.execute('feature', feature_sha3) }

          let(:expected_data) do
            {
              current_user_id: current_user.id,
              merge_request_id: merge_request.id,
              cause: 'new_push',
              approver_ids: [rb_approval.user_id]
            }
          end
        end
      end

      context 'when the latest push affects multiple codeowners entries' do
        let(:previous_merge_request_diff) do
          create(:merge_request_diff,
            merge_request: merge_request,
            head_commit_sha: feature_sha1,
            start_commit_sha: merge_request.target_branch_sha,
            base_commit_sha: merge_request.target_branch_sha
          )
        end

        it 'resets code owner approvals with changes' do
          service.execute('feature', feature_sha3)
          merge_request.reload

          expect(merge_request.approvals.count).to eq(1)
          expect(merge_request.approvals).to contain_exactly(security_approval)
        end

        it_behaves_like 'MergeRequests::ApprovalsResetEvent published' do
          let(:action) { service.execute('feature', feature_sha3) }

          let(:expected_data) do
            {
              current_user_id: current_user.id,
              merge_request_id: merge_request.id,
              cause: 'new_push',
              approver_ids: [js_approval.user_id, rb_approval.user_id]
            }
          end
        end
      end

      context 'when the latest push is not related to codeowners' do
        let!(:merge_request) do
          create(:merge_request,
            # Skip creating the diff so we can specify them for the context
            :skip_diff_creation,
            author: current_user,
            source_project: project,
            source_branch: 'feature2',
            target_project: project,
            target_branch: 'master'
          )
        end

        before do
          ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute
        end

        context 'and codeowners related changes were in a previous push' do
          let(:previous_merge_request_diff) do
            create(:merge_request_diff,
              merge_request: merge_request,
              head_commit_sha: feature_sha3,
              start_commit_sha: merge_request.target_branch_sha,
              base_commit_sha: merge_request.target_branch_sha
            )
          end

          it 'does not reset code owner approvals' do
            expect do
              service.execute('feature2', feature2_change_unrelated_to_codeowners)
            end.not_to change {
              merge_request.reload.approvals.count
            }
            expect(merge_request.approvals).to contain_exactly(security_approval, js_approval, rb_approval)
          end

          it_behaves_like 'MergeRequests::ApprovalsResetEvent not published' do
            let(:action) { service.execute('feature2', feature2_change_unrelated_to_codeowners) }
          end
        end
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { service.execute('feature', feature_sha3) }
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { service.execute('feature', feature_sha3) }
      end

      context 'when approvals patch_id_sha matches MergeRequest#current_patch_id_sha' do
        let(:patch_id_sha) { merge_request.current_patch_id_sha }

        it 'does not delete any code owner approvals' do
          service.execute('feature', feature_sha3)
          merge_request.reload

          expect(merge_request.approvals.count).to eq(3)
          expect(merge_request.approvals).to contain_exactly(security_approval, js_approval, rb_approval)
        end

        it_behaves_like 'MergeRequests::ApprovalsResetEvent not published' do
          let(:action) { service.execute('feature', feature_sha3) }
        end
      end
    end
  end
end
