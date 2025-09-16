# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::RefreshService, feature_category: :code_review_workflow do
  include ProjectForksHelper
  include UserHelpers

  let(:group) { create(:group) }
  let(:project) { create(:project, :repository, namespace: group, approvals_before_merge: 1, reset_approvals_on_push: true) }
  let(:forked_project) { fork_project(project, fork_user, repository: true) }

  let(:fork_user) { create(:user) }

  let(:source_branch) { 'between-create-delete-modify-move' }

  let(:merge_request) do
    create(:merge_request,
      source_project: project,
      source_branch: source_branch,
      target_branch: 'master',
      target_project: project)
  end

  let(:another_merge_request) do
    create(:merge_request,
      source_project: project,
      source_branch: source_branch,
      target_branch: 'test',
      target_project: project)
  end

  let(:forked_merge_request) do
    create(:merge_request,
      source_project: forked_project,
      source_branch: source_branch,
      target_branch: 'master',
      target_project: project)
  end

  let(:oldrev) { TestEnv::BRANCH_SHA[source_branch] }
  let(:newrev) { TestEnv::BRANCH_SHA['after-create-delete-modify-move'] } # Pretend source_branch is now updated
  let(:service) { described_class.new(project: project, current_user: current_user) }
  let(:current_user) { merge_request.author }

  subject { service.execute(oldrev, newrev, "refs/heads/#{source_branch}") }

  describe '#execute' do
    it 'checks merge train status' do
      expect_next_instance_of(MergeTrains::CheckStatusService, project, current_user) do |service|
        expect(service).to receive(:execute).with(project, source_branch, newrev)
      end

      subject
    end

    context 'when branch is deleted' do
      let(:newrev) { Gitlab::Git::SHA1_BLANK_SHA }

      it 'does not check merge train status' do
        expect(MergeTrains::CheckStatusService).not_to receive(:new)

        subject
      end
    end

    describe '#update_approvers_for_target_branch_merge_requests' do
      shared_examples_for 'does not refresh the code owner rules' do
        specify do
          expect(::MergeRequests::SyncCodeOwnerApprovalRules).not_to receive(:new)
          subject
        end
      end

      subject { service.execute(oldrev, newrev, "refs/heads/master") }

      let(:enable_code_owner) { true }
      let!(:protected_branch) { create(:protected_branch, name: 'master', project: project, code_owner_approval_required: true) }
      let(:newrev) { TestEnv::BRANCH_SHA['with-codeowners'] }

      before do
        stub_licensed_features(code_owner_approval_required: true, code_owners: enable_code_owner)
      end

      context 'when the feature flags are enabled' do
        context 'when the branch is protected' do
          context 'when code owners file is updated' do
            let(:irrelevant_merge_request) { another_merge_request }
            let(:relevant_merge_request) { merge_request }

            context 'when not on the merge train' do
              it 'refreshes the code owner rules for all relevant merge requests' do
                fake_refresh_service = instance_double(::MergeRequests::SyncCodeOwnerApprovalRules)

                expect(::MergeRequests::SyncCodeOwnerApprovalRules)
                  .to receive(:new).with(relevant_merge_request).and_return(fake_refresh_service)
                expect(fake_refresh_service).to receive(:execute)

                expect(::MergeRequests::SyncCodeOwnerApprovalRules)
                  .not_to receive(:new).with(irrelevant_merge_request)

                subject
              end
            end

            context 'when on the merge train' do
              let(:merge_request) do
                create(
                  :merge_request,
                  :on_train,
                  source_project: project,
                  source_branch: source_branch,
                  target_branch: 'master',
                  target_project: project
                )
              end

              it_behaves_like 'does not refresh the code owner rules'
            end
          end

          context 'when code owners file is not updated' do
            let(:newrev) { TestEnv::BRANCH_SHA['after-create-delete-modify-move'] }

            it_behaves_like 'does not refresh the code owner rules'
          end

          context 'when the branch is deleted' do
            let(:newrev) { Gitlab::Git::SHA1_BLANK_SHA }

            it_behaves_like 'does not refresh the code owner rules'
          end

          context 'when the branch is created' do
            let(:oldrev) { Gitlab::Git::SHA1_BLANK_SHA }

            it_behaves_like 'does not refresh the code owner rules'
          end
        end

        context 'when the branch is not protected' do
          let(:protected_branch) { nil }

          it_behaves_like 'does not refresh the code owner rules'
        end
      end

      context 'when code_owners is disabled' do
        let(:enable_code_owner) { false }

        it_behaves_like 'does not refresh the code owner rules'
      end
    end

    describe '#trigger_suggested_reviewers_fetch' do
      using RSpec::Parameterized::TableSyntax

      where(:project_can_suggest, :merge_request_can_suggest, :triggered) do
        true  | true  | true
        true  | false | false
        false | true  | false
        false | false | false
      end

      with_them do
        before do
          allow(project).to receive(:can_suggest_reviewers?).and_return(project_can_suggest)

          allow(merge_request).to receive(:can_suggest_reviewers?).and_return(merge_request_can_suggest)
          allow(service).to receive(:merge_requests_for_source_branch).and_return([merge_request])
        end

        it do
          if triggered
            expect(::MergeRequests::FetchSuggestedReviewersWorker).to receive(:perform_async).with(merge_request.id)
          else
            expect(::MergeRequests::FetchSuggestedReviewersWorker).not_to receive(:perform_async).with(merge_request.id)
          end

          subject
        end
      end
    end

    describe '#sync_any_merge_request_approval_rules' do
      let(:merge_request_1) { merge_request }
      let(:merge_request_2) { another_merge_request }

      let!(:scan_result_policy_read) { create(:scan_result_policy_read, :targeting_commits, project: project) }

      it 'enqueues SyncAnyMergeRequestApprovalRulesWorker for all merge requests with the same source branch' do
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request_1.id)
        )
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request_2.id)
        )

        subject
      end

      context 'when scan_result_policy_read does not target commits' do
        let!(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          subject
        end
      end

      context 'without scan_result_policy_read' do
        let!(:scan_result_policy_read) { nil }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          subject
        end
      end
    end

    describe '#sync_unenforceable_approval_rules' do
      shared_examples 'it enqueues the UnenforceablePolicyRulesNotificationWorker' do
        it 'enqueues the expected UnenforceablePolicyRulesNotificationWorker' do
          expect(Security::UnenforceablePolicyRulesNotificationWorker).to(
            receive(:perform_async).with(merge_request.id)
          )

          subject
        end
      end

      shared_examples 'it does not enqueue the UnenforceablePolicyRulesNotificationWorker' do
        it 'does not enqueue the UnenforceablePolicyRulesNotificationWorker' do
          expect(Security::UnenforceablePolicyRulesNotificationWorker).not_to(
            receive(:perform_async).with(merge_request.id)
          )

          subject
        end
      end

      context 'when the merge request has no pipeline' do
        let(:merge_request) do
          create(:merge_request,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'master',
            target_project: project)
        end

        it_behaves_like 'it enqueues the UnenforceablePolicyRulesNotificationWorker'
      end

      context 'when the merge request has a pipeline' do
        let(:merge_request) do
          create(:merge_request,
            :with_head_pipeline,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'master',
            target_project: project)
        end

        it_behaves_like 'it does not enqueue the UnenforceablePolicyRulesNotificationWorker'
      end

      context 'when the merge request is created for a different source branch' do
        let(:merge_request) do
          create(:merge_request,
            source_project: project,
            source_branch: 'feature',
            target_branch: 'master',
            target_project: project
          )
        end

        it_behaves_like 'it does not enqueue the UnenforceablePolicyRulesNotificationWorker'
      end
    end

    describe '#sync_preexisting_states_approval_rules' do
      let(:irrelevant_merge_request) { another_merge_request }
      let(:relevant_merge_request) { merge_request }

      let!(:scan_finding_rule) do
        create(:report_approver_rule, :scan_finding, merge_request: relevant_merge_request)
      end

      it 'enqueues SyncPreexistingStatesApprovalRulesWorker' do
        expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
          receive(:perform_async).with(relevant_merge_request.id)
        )
        expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).not_to(
          receive(:perform_async).with(irrelevant_merge_request.id)
        )

        subject
      end

      context 'with license_finding rule' do
        let!(:license_finding_rule) do
          create(:report_approver_rule, :license_scanning, merge_request: relevant_merge_request)
        end

        it 'enqueues SyncPreexistingStatesApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
            receive(:perform_async).with(relevant_merge_request.id)
          )

          subject
        end
      end

      context 'without scan_finding rule' do
        let!(:scan_finding_rule) { nil }

        it 'does not enqueue SyncPreexistingStatesApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).not_to receive(:perform_async)

          subject
        end
      end
    end

    describe '#update_approvers_for_source_branch_merge_requests' do
      let(:owner) { create(:user, username: 'default-codeowner') }
      let(:current_user) { merge_request.author }
      let(:service) { described_class.new(project: project, current_user: current_user) }
      let(:enable_code_owner) { true }
      let(:enable_report_approver_rules) { true }
      let(:notification_service) { double(:notification_service) }

      before do
        stub_licensed_features(code_owners: enable_code_owner)
        stub_licensed_features(report_approver_rules: enable_report_approver_rules)

        allow(service).to receive(:mark_pending_todos_done)
        allow(service).to receive(:notify_about_push)
        allow(service).to receive(:execute_hooks)
        allow(service).to receive(:notification_service).and_return(notification_service)

        group.add_maintainer(fork_user)

        merge_request
        another_merge_request
        forked_merge_request
      end

      it 'gets called in a specific order' do
        allow_any_instance_of(MergeRequests::BaseService).to receive(:inspect).and_return(true)
        expect(service).to receive(:reload_merge_requests).ordered
        expect(service).to receive(:update_approvers_for_source_branch_merge_requests).ordered
        expect(service).to receive(:reset_approvals_for_merge_requests).ordered

        subject
      end

      context "creating approval_rules" do
        shared_examples_for 'creates an approval rule based on current diff' do
          it "creates expected approval rules" do
            expect(another_merge_request.approval_rules.size).to eq(approval_rules_size)
            expect(another_merge_request.approval_rules.first.rule_type).to eq('code_owner')
          end
        end

        before do
          project.repository.create_file(owner, 'CODEOWNERS', file, branch_name: 'test', message: 'codeowners')

          subject
        end

        context 'with a non-sectional codeowners file' do
          let_it_be(:file) do
            File.read(Rails.root.join('ee', 'spec', 'fixtures', 'codeowners_example'))
          end

          it_behaves_like 'creates an approval rule based on current diff' do
            let(:approval_rules_size) { 3 }
          end
        end

        context 'with a sectional codeowners file' do
          let_it_be(:file) do
            File.read(Rails.root.join('ee', 'spec', 'fixtures', 'sectional_codeowners_example'))
          end

          it_behaves_like 'creates an approval rule based on current diff' do
            let(:approval_rules_size) { 9 }
          end
        end
      end

      context 'when code owners disabled' do
        let(:enable_code_owner) { false }

        it 'does nothing' do
          expect(::Gitlab::CodeOwners).not_to receive(:for_merge_request)

          subject
        end
      end

      context 'when code owners enabled' do
        let(:relevant_merge_requests) { [merge_request, another_merge_request] }

        it 'refreshes the code owner rules for all relevant merge requests' do
          fake_refresh_service = instance_double(::MergeRequests::SyncCodeOwnerApprovalRules)

          relevant_merge_requests.each do |merge_request|
            expect(::MergeRequests::SyncCodeOwnerApprovalRules)
              .to receive(:new).with(merge_request).and_return(fake_refresh_service)
            expect(fake_refresh_service).to receive(:execute)
          end

          subject
        end
      end

      context 'when report_approver_rules enabled, with approval_rule enabled' do
        let(:relevant_merge_requests) { [merge_request, another_merge_request] }

        it 'refreshes the report_approver rules for all relevant merge requests' do
          relevant_merge_requests.each do |merge_request|
            expect_next_instance_of(::MergeRequests::SyncReportApproverApprovalRules, merge_request, current_user) do |service|
              expect(service).to receive(:execute)
            end
          end

          subject
        end
      end
    end

    describe 'Pipelines for merge requests', :sidekiq_inline do
      let(:service) { described_class.new(project: project, current_user: current_user) }
      let(:project) { create(:project, :repository, namespace: group, reset_approvals_on_push: true) }
      let(:current_user) { merge_request.author }

      let(:config) do
        {
          test: {
            stage: 'test',
            script: 'echo',
            only: ['merge_requests']
          }
        }
      end

      before do
        project.add_developer(current_user)
        project.update!(merge_pipelines_enabled: true)
        stub_licensed_features(merge_pipelines: true)
        stub_ci_pipeline_yaml_file(YAML.dump(config))
      end

      it 'creates a merge request pipeline' do
        expect { subject }
          .to change { merge_request.pipelines_for_merge_request.count }.by(1)

        expect(merge_request.all_pipelines.last).to be_merged_result_pipeline
      end

      context 'when MergeRequestUpdateWorker is retried by an exception' do
        it 'does not re-create a duplicate merge request pipeline' do
          expect do
            service.execute(oldrev, newrev, "refs/heads/#{source_branch}")
          end.to change { merge_request.pipelines_for_merge_request.count }.by(1)

          expect do
            service.execute(oldrev, newrev, "refs/heads/#{source_branch}")
          end.not_to change { merge_request.pipelines_for_merge_request.count }
        end
      end
    end

    context 'when user is approver' do
      let_it_be(:user) { create(:user) }

      let(:merge_request) do
        create(:merge_request,
          source_project: project,
          source_branch: 'master',
          target_branch: 'feature',
          target_project: project,
          merge_when_pipeline_succeeds: true,
          merge_user: user)
      end

      let(:forked_project) { fork_project(project, user, repository: true) }
      let(:forked_merge_request) do
        create(:merge_request,
          source_project: forked_project,
          source_branch: 'master',
          target_branch: 'feature',
          target_project: project)
      end

      let(:commits) { merge_request.commits }
      let(:oldrev) { commits.last.id }
      let(:newrev) { commits.first.id }
      let(:approver) { create(:user) }

      before do
        group.add_owner(user)

        merge_request.approvals.create!(user_id: user.id)
        forked_merge_request.approvals.create!(user_id: user.id)

        project.add_developer(approver)

        perform_enqueued_jobs do
          merge_request.update!(approver_ids: [approver].map(&:id).join(','))
          forked_merge_request.update!(approver_ids: [approver].map(&:id).join(','))
        end
      end

      def approval_todos(merge_request)
        Todo.where(action: Todo::APPROVAL_REQUIRED, target: merge_request)
      end

      context 'push to origin repo source branch', :sidekiq_inline do
        let(:notification_service) { spy('notification_service') }

        before do
          allow(service).to receive(:execute_hooks)
          allow(NotificationService).to receive(:new) { notification_service }
        end

        it 'resets approvals and does not create approval todos for regular and for merge request' do
          service.execute(oldrev, newrev, 'refs/heads/master')
          reload_mrs

          expect(merge_request.approvals).to be_empty
          expect(forked_merge_request.approvals).not_to be_empty
          expect(approval_todos(merge_request).map(&:user)).to be_empty
          expect(approval_todos(forked_merge_request)).to be_empty
        end

        context "in the time it takes to reset approvals" do
          before do
            allow(MergeRequestResetApprovalsWorker).to receive(:perform_in).and_return(nil)
            # Running the approval refresh service would normally run this worker and remove
            # the flag after 10 seconds, but in our test environment "perform_in" happens
            # instantly... so for testing we're just simulating a long run by returning nil

            service.execute(oldrev, newrev, 'refs/heads/master')
          end

          it "prevents merging" do
            expect(merge_request.approval_state.temporarily_unapproved?).to be_truthy
          end

          it "removes the unmergeable flag after the allotted time" do
            merge_request.approval_state.expire_unapproved_key!

            expect(merge_request.approval_state.temporarily_unapproved?).to be_falsey
          end
        end

        context "with a merge request on a merge train" do
          before do
            allow_any_instance_of(MergeRequest).to receive(:merge_train_car).and_return(true)
          end

          it "does not add an umergeable flag" do
            expect(merge_request.approval_state.temporarily_unapproved?).to be_falsey
          end
        end
      end

      context 'push to origin repo target branch' do
        context 'when all MRs to the target branch had diffs' do
          before do
            service.execute(oldrev, newrev, 'refs/heads/feature')
            reload_mrs
          end

          it 'does not reset approvals' do
            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).not_to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end
      end

      context 'push to fork repo source branch' do
        let(:service) { described_class.new(project: forked_project, current_user: user) }

        def refresh
          allow(service).to receive(:execute_hooks)
          service.execute(oldrev, newrev, 'refs/heads/master')
          reload_mrs
        end

        context 'open fork merge request' do
          it 'resets approvals and does not create approval todo in fork', :sidekiq_might_not_need_inline do
            refresh

            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end

        context 'closed fork merge request' do
          before do
            forked_merge_request.close!
          end

          it 'resets approvals', :sidekiq_might_not_need_inline do
            refresh

            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end
      end

      context 'push to fork repo target branch' do
        describe 'changes to merge requests' do
          before do
            described_class.new(project: forked_project, current_user: user).execute(oldrev, newrev, 'refs/heads/feature')
            reload_mrs
          end

          it 'does not reset approvals', :sidekiq_might_not_need_inline do
            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).not_to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end
      end

      context 'push to origin repo target branch after fork project was removed' do
        before do
          forked_project.destroy!
          service.execute(oldrev, newrev, 'refs/heads/feature')
          reload_mrs
        end

        it 'does not reset approvals' do
          expect(merge_request.approvals).not_to be_empty
          expect(forked_merge_request.approvals).not_to be_empty
          expect(approval_todos(merge_request)).to be_empty
          expect(approval_todos(forked_merge_request)).to be_empty
        end
      end

      context 'resetting approvals if they are enabled', :sidekiq_inline do
        context 'when approvals_before_merge is disabled' do
          before do
            project.update!(approvals_before_merge: 0)
            allow(service).to receive(:execute_hooks)
            service.execute(oldrev, newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'resets approvals and does not create approval todo for approver' do
            expect(merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
          end
        end

        context 'when reset_approvals_on_push is disabled' do
          before do
            project.update!(reset_approvals_on_push: false)
            allow(service).to receive(:execute_hooks)
            service.execute(oldrev, newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'does not reset approvals' do
            expect(merge_request.approvals).not_to be_empty
            expect(approval_todos(merge_request)).to be_empty
          end

          context 'when enforced by policy' do
            let(:configuration) { create(:security_orchestration_policy_configuration) }

            let(:scan_result_policy_read) do
              create(
                :scan_result_policy_read,
                :remove_approvals_with_new_commit,
                security_orchestration_policy_configuration: configuration,
                project: project)
            end

            let!(:violation) do
              create(
                :scan_result_policy_violation,
                merge_request: merge_request,
                scan_result_policy_read: scan_result_policy_read)
            end

            let!(:approval_rule) do
              create(
                :report_approver_rule,
                merge_request: merge_request,
                scan_result_policy_read: scan_result_policy_read)
            end

            it 'resets approvals' do
              service.execute(oldrev, newrev, 'refs/heads/master')

              expect(merge_request.approvals).to be_empty
            end
          end
        end

        context 'when the rebase_commit_sha on the MR matches the pushed SHA' do
          before do
            merge_request.update!(rebase_commit_sha: newrev)
            allow(service).to receive(:execute_hooks)
            service.execute(oldrev, newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'resets approvals' do
            expect(merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
          end
        end

        context 'when there are approvals', :sidekiq_inline do
          context 'closed merge request' do
            before do
              merge_request.close!
              allow(service).to receive(:execute_hooks)
              service.execute(oldrev, newrev, 'refs/heads/master')
              reload_mrs
            end

            it 'resets the approvals' do
              expect(merge_request.approvals).to be_empty
              expect(approval_todos(merge_request)).to be_empty
            end
          end

          context 'opened merge request' do
            before do
              allow(service).to receive(:execute_hooks)
              service.execute(oldrev, newrev, 'refs/heads/master')
              reload_mrs
            end

            it 'resets the approvals' do
              expect(merge_request.approvals).to be_empty
              expect(approval_todos(merge_request)).to be_empty
            end
          end
        end
      end

      def reload_mrs
        merge_request.reload
        forked_merge_request.reload
      end
    end

    context 'when user has requested changes' do
      before do
        create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project,
          user: current_user)
      end

      context 'when project does not have the right license' do
        before do
          stub_licensed_features(requested_changes_block_merge_request: false)
        end

        it 'does not call merge_request.destroy_requested_changes' do
          expect { subject }.not_to change { merge_request.requested_changes.count }.from(1)
        end
      end

      context 'when licensed feature is available' do
        before do
          stub_licensed_features(requested_changes_block_merge_request: true)
        end

        context 'when merge_requests_disable_committers_approval is disabled' do
          before do
            project.update!(merge_requests_disable_committers_approval: false)
          end

          it 'does not call merge_request.destroy_requested_changes' do
            expect { subject }.not_to change { merge_request.requested_changes.count }.from(1)
          end
        end

        context 'when merge_requests_disable_committers_approval is enabled' do
          before do
            project.update!(merge_requests_disable_committers_approval: true)
          end

          it 'calls merge_request.destroy_requested_changes' do
            expect { subject }.to change { merge_request.requested_changes.count }.from(1).to(0)
          end

          context 'when user is a reviewer' do
            before do
              create(:merge_request_reviewer, merge_request: merge_request, reviewer: current_user, state: 'reviewed')
              project.add_developer(current_user)
            end

            it 'updates reviewer state to unreviewed' do
              subject

              expect(merge_request.merge_request_reviewers.first).to be_unreviewed
            end
          end
        end
      end
    end

    describe 'schedule_duo_code_review' do
      let(:ai_review_allowed) { true }

      before do
        allow(project)
          .to receive(:auto_duo_code_review_enabled)
          .and_return(auto_duo_code_review)

        allow_next_found_instance_of(MergeRequest) do |mr|
          allow(mr)
            .to receive(:ai_review_merge_request_allowed?)
            .and_return(ai_review_allowed)
        end
      end

      context 'when auto_duo_code_review_enabled is false' do
        let(:auto_duo_code_review) { false }

        it 'does not call ::Llm::ReviewMergeRequestService' do
          expect(Llm::ReviewMergeRequestService).not_to receive(:new)

          subject
        end
      end

      context 'when auto_duo_code_review_enabled is true' do
        let(:auto_duo_code_review) { true }

        before do
          create(:merge_request_diff, merge_request: merge_request, state: :empty)
        end

        context 'when merge request is a draft' do
          let(:merge_request) do
            create(
              :merge_request,
              :draft_merge_request,
              source_project: project,
              source_branch: source_branch,
              target_branch: 'master',
              target_project: project
            )
          end

          it 'does not call ::Llm::ReviewMergeRequestService' do
            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            subject
          end
        end

        context 'when previous diff is not empty' do
          before do
            create(:merge_request_diff, merge_request: merge_request)
          end

          it 'does not call ::Llm::ReviewMergeRequestService' do
            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            subject
          end
        end

        context 'when Duo Code Review bot is not assigned as a reviewer' do
          it 'does not call ::Llm::ReviewMergeRequestService' do
            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            subject
          end
        end

        context 'when Duo Code Review bot is assigned as a reviewer' do
          before do
            merge_request.reviewers = [::Users::Internal.duo_code_review_bot]
          end

          context 'when AI review feature is not allowed' do
            let(:ai_review_allowed) { false }

            it 'does not call ::Llm::ReviewMergeRequestService' do
              expect(Llm::ReviewMergeRequestService).not_to receive(:new)

              subject
            end
          end

          context 'when AI review feature is allowed' do
            let(:ai_review_allowed) { true }

            it 'calls ::Llm::ReviewMergeRequestService' do
              expect_next_instance_of(Llm::ReviewMergeRequestService, current_user, merge_request) do |svc|
                expect(svc).to receive(:execute)
              end

              subject
            end
          end
        end
      end
    end
  end

  describe '#abort_ff_merge_requests_with_when_pipeline_succeeds' do
    let_it_be(:project) { create(:project, :repository, merge_method: 'ff') }
    let_it_be(:author) { create_user_from_membership(project, :developer) }
    let_it_be(:user) { create(:user) }

    let_it_be(:merge_request, refind: true) do
      create(
        :merge_request,
        author: author,
        source_project: project,
        source_branch: 'feature',
        target_branch: 'master',
        target_project: project,
        auto_merge_enabled: true,
        merge_user: user
      )
    end

    let_it_be(:newrev) do
      project
        .repository
        .create_file(
          user,
          'test1.txt',
          'Test data',
          message: 'Test commit',
          branch_name: 'master'
        )
    end

    let_it_be(:oldrev) do
      project
        .repository
        .commit(newrev)
        .parent_id
    end

    let(:refresh_service) { described_class.new(project: project, current_user: user) }

    before do
      merge_request.auto_merge_strategy = auto_merge_strategy
      merge_request.save!

      refresh_service.execute(oldrev, newrev, 'refs/heads/master')
      merge_request.reload
    end

    context 'with add to merge train when checks pass strategy' do
      let(:auto_merge_strategy) do
        AutoMergeService::STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_CHECKS_PASS
      end

      it_behaves_like 'maintained merge requests for auto merges'
    end

    context 'with merge train strategy' do
      let(:auto_merge_strategy) { AutoMergeService::STRATEGY_MERGE_TRAIN }

      it_behaves_like 'maintained merge requests for auto merges'
    end
  end
end
