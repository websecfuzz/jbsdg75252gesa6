# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::UpdateService, :mailer, feature_category: :code_review_workflow do
  include ProjectForksHelper

  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:label) { create(:label, project: project) }
  let(:label2) { create(:label) }
  let(:current_user) { user }

  let(:merge_request) do
    create(
      :merge_request,
      :simple,
      title: 'Old title',
      description: "FYI #{user2.to_reference}",
      assignee_id: user3.id,
      source_project: project,
      author: create(:user)
    )
  end

  before do
    project.add_maintainer(user)
    project.add_developer(user2)
    project.add_developer(user3)
  end

  describe '#execute' do
    it_behaves_like 'existing issuable with scoped labels' do
      let(:issuable) { merge_request }
      let(:parent) { project }
    end

    context 'when MR is merged' do
      let(:issuable) { create(:merge_request, :simple, :merged, source_project: project) }
      let(:parent) { project }

      it_behaves_like 'merged MR with scoped labels and lock_on_merge'

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(enforce_locked_labels_on_merge: false)
        end

        it_behaves_like 'existing issuable with scoped labels'
      end
    end

    it_behaves_like 'service with multiple reviewers' do
      let(:opts) { {} }
      let(:execute) { update_merge_request(opts) }
    end

    def update_merge_request(opts)
      described_class.new(project: project, current_user: current_user, params: opts).execute(merge_request)
    end

    it 'publishes updated event' do
      expect { update_merge_request(title: 'New title') }
        .to publish_event(::MergeRequests::UpdatedEvent).with(
          merge_request_id: merge_request.id
        )
    end

    context 'when code owners changes' do
      let(:code_owner) { create(:user) }

      before do
        project.add_maintainer(code_owner)

        allow(merge_request).to receive(:code_owners).and_return([], [code_owner])
      end

      it 'does not create any todos' do
        expect do
          update_merge_request(title: 'New title')
        end.not_to change { Todo.count }
      end

      it 'does not send any emails' do
        expect do
          update_merge_request(title: 'New title')
        end.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context 'when approvals_before_merge changes' do
      using RSpec::Parameterized::TableSyntax

      where(:project_value, :mr_before_value, :mr_after_value, :result) do
        3 | 4   | 5   | 5
        3 | 4   | nil | 3
        3 | nil | 5   | 5
      end

      with_them do
        let(:project) { create(:project, :repository, approvals_before_merge: project_value) }

        it "does not update" do
          merge_request.update!(approvals_before_merge: mr_before_value)
          rule = create(:approval_merge_request_rule, merge_request: merge_request)

          update_merge_request(approvals_before_merge: mr_after_value)

          expect(rule.reload.approvals_required).to eq(0)
        end
      end
    end

    context 'for override requested changes' do
      context 'for user can not merge' do
        let(:current_user) { merge_request.author }

        it 'does not update' do
          expect do
            update_merge_request(override_requested_changes: true)
          end.not_to change { merge_request.override_requested_changes? }
        end
      end

      it 'updates override_requested_changes' do
        expect do
          update_merge_request(override_requested_changes: true)
        end.to change { merge_request.override_requested_changes? }.from(false).to(true)
      end

      it 'calls SystemNoteService.override_requested_changes' do
        expect_next_instance_of(::SystemNotes::MergeRequestsService) do |service|
          expect(service).to receive(:override_requested_changes).with(true)
        end

        update_merge_request(override_requested_changes: true)
      end

      it 'publishes a OverrideRequestedChanges state event' do
        expect do
          update_merge_request(override_requested_changes: true)
        end.to publish_event(MergeRequests::OverrideRequestedChangesStateEvent).with({
          current_user_id: current_user.id,
          merge_request_id: merge_request.id
        })
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { update_merge_request(override_requested_changes: true) }
      end
    end

    context 'merge' do
      let(:opts) { { merge: merge_request.diff_head_sha } }

      context 'when not approved' do
        before do
          merge_request.update!(approvals_before_merge: 1)

          perform_enqueued_jobs do
            update_merge_request(opts)
            @merge_request = MergeRequest.find(merge_request.id)
          end
        end

        it { expect(@merge_request).to be_valid }
        it { expect(@merge_request.state).to eq('opened') }
      end

      context 'when approved' do
        before do
          merge_request.update!(approvals_before_merge: 1)
          merge_request.approvals.create!(user: user)

          perform_enqueued_jobs do
            update_merge_request(opts)
            @merge_request = MergeRequest.find(merge_request.id)
          end
        end

        it { expect(@merge_request).to be_valid }

        it 'is in the "merge" state', :sidekiq_might_not_need_inline do
          expect(@merge_request.state).to eq('merged')
        end
      end
    end

    context 'when the approvers change' do
      let(:existing_approver) { create(:user) }
      let(:removed_approver) { create(:user) }
      let(:new_approver) { create(:user) }

      before do
        project.add_developer(existing_approver)
        project.add_developer(removed_approver)
        project.add_developer(new_approver)

        perform_enqueued_jobs do
          update_merge_request(approver_ids: [existing_approver, removed_approver].map(&:id).join(','))
        end

        ActionMailer::Base.deliveries.clear
      end

      context 'when an approver is added and an approver is removed' do
        before do
          perform_enqueued_jobs do
            update_merge_request(approver_ids: [new_approver, existing_approver].map(&:id).join(','))
          end
        end

        it 'does not send emails to the new approvers' do
          should_not_email(new_approver)
        end

        it 'does not send emails to the existing approvers' do
          should_not_email(existing_approver)
        end

        it 'does not send emails to the removed approvers' do
          should_not_email(removed_approver)
        end
      end

      context 'when the approvers are set to the same values' do
        it 'does not create any todos' do
          expect do
            update_merge_request(approver_ids: [existing_approver, removed_approver].map(&:id).join(','))
          end.not_to change { Todo.count }
        end

        it 'does not send any emails' do
          expect do
            update_merge_request(approver_ids: [existing_approver, removed_approver].map(&:id).join(','))
          end.not_to change { ActionMailer::Base.deliveries.count }
        end
      end
    end

    context 'updating target_branch' do
      let(:existing_approver) { create(:user) }
      let(:new_approver) { create(:user) }

      before do
        project.add_developer(existing_approver)
        project.add_developer(new_approver)

        perform_enqueued_jobs do
          update_merge_request(approver_ids: "#{existing_approver.id},#{new_approver.id}")
        end

        merge_request.approvals.create!(user_id: existing_approver.id, patch_id_sha: merge_request.current_patch_id_sha)
      end

      shared_examples 'reset all approvals' do
        it 'resets approvals when target_branch is changed' do
          update_merge_request(target_branch: 'video')

          expect(merge_request.reload.approvals).to be_empty
        end

        it 'does not publish MergeRequests::ApprovalsResetEvent' do
          expect { update_merge_request(target_branch: 'video') }
            .not_to publish_event(MergeRequests::ApprovalsResetEvent)
        end
      end

      context 'when reset_approvals_on_push is set to true' do
        before do
          merge_request.target_project.update!(reset_approvals_on_push: true)
        end

        it_behaves_like 'reset all approvals'
      end

      context 'when selective_code_owner_removals is set to true' do
        before do
          merge_request.target_project.update!(
            reset_approvals_on_push: false,
            project_setting_attributes: { selective_code_owner_removals: true }
          )
        end

        it_behaves_like 'reset all approvals'
      end

      it_behaves_like 'audits security policy branch bypass' do
        before do
          merge_request.update!(target_branch: 'master')
        end

        let(:execute) { update_merge_request(target_branch: 'main') }
      end
    end

    context 'updating blocking merge requests' do
      it 'delegates to MergeRequests::UpdateBlocksService' do
        expect(MergeRequests::UpdateBlocksService)
          .to receive(:extract_params!)
          .and_return(:extracted_params)

        expect_next_instance_of(MergeRequests::UpdateBlocksService) do |service|
          expect(service.merge_request).to eq(merge_request)
          expect(service.current_user).to eq(user)
          expect(service.params).to eq(:extracted_params)

          expect(service).to receive(:execute)
        end

        update_merge_request({})
      end
    end

    context 'reset_approval_rules_to_defaults param' do
      let!(:existing_any_rule) { create(:any_approver_rule, merge_request: merge_request) }
      let!(:existing_rule) { create(:approval_merge_request_rule, merge_request: merge_request) }
      let(:rules) { merge_request.reload.approval_rules }

      shared_examples_for 'undeletable existing approval rules' do
        it 'does not delete existing approval rules' do
          aggregate_failures do
            expect(rules).not_to be_empty
            expect(rules).to include(existing_any_rule)
            expect(rules).to include(existing_rule)
          end
        end
      end

      context 'when approval rules can be overridden' do
        before do
          merge_request.project.update!(disable_overriding_approvers_per_merge_request: false)
        end

        context 'when not set' do
          before do
            update_merge_request({})
          end

          it_behaves_like 'undeletable existing approval rules'
        end

        context 'when set to false' do
          before do
            update_merge_request(reset_approval_rules_to_defaults: false)
          end

          it_behaves_like 'undeletable existing approval rules'
        end

        context 'when set to true' do
          context 'and approval_rules_attributes param is not set' do
            context 'when MR is not merged' do
              before do
                update_merge_request(reset_approval_rules_to_defaults: true)
              end

              it 'deletes existing approval rules' do
                expect(rules).to be_empty
              end
            end

            context 'when MR is merged' do
              let(:merge_request) { create(:merge_request) }

              before do
                merge_request.mark_as_merged!

                update_merge_request(reset_approval_rules_to_defaults: true)
              end

              it_behaves_like 'undeletable existing approval rules'
            end
          end

          context 'and approval_rules_attributes param is set' do
            context 'when MR is not merged' do
              before do
                update_merge_request(
                  reset_approval_rules_to_defaults: true,
                  approval_rules_attributes: [{ name: 'New Rule', approvals_required: 1 }]
                )
              end

              it 'deletes existing approval rules and creates new one' do
                aggregate_failures do
                  expect(rules.size).to eq(1)
                  expect(rules).not_to include(existing_any_rule)
                  expect(rules).not_to include(existing_rule)
                end
              end
            end

            context 'when MR is merged' do
              let(:merge_request) { create(:merge_request) }

              before do
                merge_request.mark_as_merged!

                update_merge_request(
                  reset_approval_rules_to_defaults: true,
                  approval_rules_attributes: [{ name: 'New Rule', approvals_required: 1 }]
                )
              end

              it_behaves_like 'undeletable existing approval rules'
            end
          end
        end
      end

      context 'when approval rules cannot be overridden' do
        before do
          merge_request.project.update!(disable_overriding_approvers_per_merge_request: true)
          update_merge_request(reset_approval_rules_to_defaults: true)
        end

        it_behaves_like 'undeletable existing approval rules'
      end
    end

    context 'when called inside an ActiveRecord transaction' do
      it 'does not attempt to update code owner approval rules' do
        expect(::MergeRequests::SyncCodeOwnerApprovalRulesWorker).not_to receive(:perform_async)

        update_merge_request(title: 'Title')
      end
    end

    context 'updating reviewer_ids' do
      it 'updates the tracking when user ids are valid' do
        expect(Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter)
          .to receive(:track_users_review_requested)
          .with(users: match_array([user, user2]))

        update_merge_request(reviewer_ids: [user.id, user2.id])
      end

      it 'sets reviewer state as requested changes if user has previously requested changes' do
        create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project,
          user: user)

        update_merge_request(reviewer_ids: [user.id, user2.id])

        expect(merge_request.find_reviewer(user)).to be_requested_changes
        expect(merge_request.find_reviewer(user2)).to be_unreviewed
      end

      context 'when assigning Duo Code Review bot as a reviewer' do
        before do
          allow(merge_request.merge_request_diff).to receive_messages(
            persisted?: persisted,
            empty?: empty
          )

          allow(merge_request).to receive(:ai_review_merge_request_allowed?)
            .with(current_user)
            .and_return(ai_review_allowed)
        end

        context 'when AI review feature is not allowed' do
          let(:ai_review_allowed) { false }
          let(:persisted) { true }
          let(:empty) { false }

          it 'does not call ::Llm::ReviewMergeRequestService' do
            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            update_merge_request(reviewer_ids: [::Users::Internal.duo_code_review_bot.id])
          end
        end

        context 'when AI review feature is allowed' do
          let(:ai_review_allowed) { true }
          let(:empty) { false }

          context 'when the merge_request_diff is not persisted yet' do
            let(:persisted) { false }

            it 'does not call ::Llm::ReviewMergeRequestService' do
              expect(Llm::ReviewMergeRequestService).not_to receive(:new)

              update_merge_request(reviewer_ids: [::Users::Internal.duo_code_review_bot.id])
            end
          end

          context 'when the merge_request_diff is persisted' do
            let(:persisted) { true }

            it 'calls ::Llm::ReviewMergeRequestService' do
              expect_next_instance_of(Llm::ReviewMergeRequestService, current_user, merge_request) do |svc|
                expect(svc).to receive(:execute)
              end

              update_merge_request(reviewer_ids: [::Users::Internal.duo_code_review_bot.id])
            end

            context 'when merge_request_diff is empty' do
              let(:empty) { true }

              it 'does not call ::Llm::ReviewMergeRequestService' do
                expect(Llm::ReviewMergeRequestService).not_to receive(:new)

                update_merge_request(reviewer_ids: [::Users::Internal.duo_code_review_bot.id])
              end
            end
          end
        end
      end
    end

    describe 'capture suggested_reviewer_ids', feature_category: :code_review_workflow do
      shared_examples 'not capturing suggested_reviewer_ids' do
        it 'does not capture the suggested_reviewer_ids and raise update error', :aggregate_failures do
          expect(MergeRequests::CaptureSuggestedReviewersAcceptedWorker).not_to receive(:perform_async)

          expect { update_merge_request(opts) }.not_to raise_error
        end
      end

      context 'when reviewer_ids is present' do
        context 'when suggested_reviewer_ids is present' do
          let(:opts) { { reviewer_ids: [user.id, user2.id], suggested_reviewer_ids: [user.id] } }

          it 'captures the suggested_reviewer_ids and does not raise update error', :aggregate_failures do
            expect(MergeRequests::CaptureSuggestedReviewersAcceptedWorker)
              .to receive(:perform_async)
              .with(merge_request.id, [user.id])

            expect { update_merge_request(opts) }.not_to raise_error
          end
        end

        context 'when suggested_reviewer_ids is blank' do
          let(:opts) { { reviewer_ids: [user.id, user2.id] } }

          it_behaves_like 'not capturing suggested_reviewer_ids'
        end
      end

      context 'when reviewer_ids is blank' do
        let(:opts) { { reviewer_ids: [], suggested_reviewer_ids: [user.id] } }

        it_behaves_like 'not capturing suggested_reviewer_ids'
      end
    end

    describe '#sync_any_merge_request_approval_rules' do
      let(:opts) { { target_branch: 'feature-2' } }
      let!(:scan_result_policy_read) { create(:scan_result_policy_read, :targeting_commits, project: project) }

      subject(:execute) { update_merge_request(opts) }

      it 'enqueues SyncAnyMergeRequestApprovalRulesWorker' do
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request.id)
        )

        execute
      end

      context 'when target_branch is not changing' do
        let(:opts) { {} }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end

      context 'when scan_result_policy_read does not target commits' do
        let!(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end

      context 'without scan_result_policy_read' do
        let!(:scan_result_policy_read) { nil }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end
    end

    describe '#notify_for_policy_violations' do
      let(:opts) { { target_branch: 'feature-2' } }

      subject(:execute) { update_merge_request(opts) }

      it 'enqueues Security::SyncPolicyViolationCommentWorker' do
        expect(Security::SyncPolicyViolationCommentWorker).to receive(:perform_async).with(merge_request.id)

        execute
      end

      context 'when target_branch is not changing' do
        let(:opts) { {} }

        it 'does not enqueue Security::SyncPolicyViolationCommentWorker' do
          expect(Security::SyncPolicyViolationCommentWorker).not_to receive(:perform_async)

          execute
        end
      end
    end

    describe "merge request webhooks" do
      let(:service) { described_class.new(project: project, current_user: user, params: opts) }

      let(:opts) do
        {
          title: 'New title',
          description: 'Also please fix',
          assignee_ids: [user.id],
          reviewer_ids: [],
          state_event: 'close',
          label_ids: [label.id],
          target_branch: 'target',
          force_remove_source_branch: '1',
          discussion_locked: true
        }
      end

      before do
        allow(service).to receive(:execute_hooks)

        perform_enqueued_jobs do
          @merge_request = service.execute(merge_request)
          @merge_request.reload
        end
      end

      it 'executes hooks with update action' do
        expect(service).to have_received(:execute_hooks)
          .with(
            @merge_request,
            'update',
            old_associations: {
              approval_rules: [],
              labels: [],
              mentioned_users: [],
              assignees: [user3],
              closing_issues_ids: [],
              reviewers: [],
              target_branch: "master",
              milestone: nil,
              total_time_spent: 0,
              time_change: 0,
              description: "FYI #{user2.to_reference}"
            }
          )
      end
    end

    describe 'AutoMerge::TitleDescriptionUpdateEvent' do
      let(:has_jira_key) { true }
      let(:auto_merge_enabled) { true }
      let(:title_regex) { nil }
      let(:description) { title_regex }

      before do
        allow(merge_request).to receive(:has_jira_issue_keys?).and_return(has_jira_key)
        merge_request.update!(auto_merge_enabled: true, merge_user: user) if auto_merge_enabled
        project.update!(merge_request_title_regex_description: description, merge_request_title_regex: title_regex)
      end

      context 'when the description changes' do
        let(:update_params) { { description: 'New description' } }

        context 'when the MR has a jira key' do
          it_behaves_like 'it publishes the AutoMerge::TitleDescriptionUpdateEvent once'

          context 'when auto merge is not enabled' do
            let(:auto_merge_enabled) { false }

            it_behaves_like 'it does not publish the AutoMerge::TitleDescriptionUpdateEvent'
          end
        end

        context 'when the description or title does not have a jira key' do
          let(:has_jira_key) { false }

          it_behaves_like 'it does not publish the AutoMerge::TitleDescriptionUpdateEvent'
        end
      end

      context 'when the title changes' do
        let(:update_params) { { title: 'New title' } }

        context 'when the MR has a jira key' do
          context 'when project has no required regex' do
            let(:title_regex) { nil }

            it_behaves_like 'it publishes the AutoMerge::TitleDescriptionUpdateEvent once'

            context 'when auto merge is not enabled' do
              let(:auto_merge_enabled) { false }

              it_behaves_like 'it does not publish the AutoMerge::TitleDescriptionUpdateEvent'
            end
          end

          context 'when project has a required regex' do
            let(:title_regex) { 'test' }

            it_behaves_like 'it publishes the AutoMerge::TitleDescriptionUpdateEvent once'
          end
        end

        context 'when the MR does not have a jira key' do
          let(:has_jira_key) { false }

          context 'when the project has no required regex' do
            let(:title_regex) { nil }

            it_behaves_like 'it does not publish the AutoMerge::TitleDescriptionUpdateEvent'
          end

          context 'when project has a required regex' do
            let(:title_regex) { 'test' }

            context 'when merge_request_title_regex ff is off' do
              before do
                stub_feature_flags(merge_request_title_regex: false)
              end

              it_behaves_like 'it does not publish the AutoMerge::TitleDescriptionUpdateEvent'
            end

            it_behaves_like 'it publishes the AutoMerge::TitleDescriptionUpdateEvent once'

            context 'when auto merge is not enabled' do
              let(:auto_merge_enabled) { false }

              it_behaves_like 'it does not publish the AutoMerge::TitleDescriptionUpdateEvent'
            end
          end
        end
      end
    end

    describe 'Automatic Duo Code Review' do
      let(:ai_review_allowed) { true }
      let(:auto_duo_code_review) { true }
      let(:duo_enabled_project_setting) { true }
      let(:duo) { ::Users::Internal.duo_code_review_bot }
      let(:old_title) { 'Draft: Awesome merge_request' }
      let(:duo_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

      let(:merge_request) do
        create(
          :merge_request,
          :simple,
          title: old_title,
          description: "This is great",
          source_project: project,
          author: create(:user)
        )
      end

      before do
        allow(project).to receive(:auto_duo_code_review_enabled).and_return(auto_duo_code_review)
        allow(project.project_setting).to receive(:duo_features_enabled?).and_return(duo_enabled_project_setting)

        create(:gitlab_subscription_add_on_purchase,
          namespace: project.namespace,
          add_on: duo_add_on)

        allow(merge_request).to receive(:ai_review_merge_request_allowed?)
          .with(user)
          .and_return(ai_review_allowed)
      end

      context 'when it became ready by wip_event the MR title changes' do
        # wip_event can be set either via UI or /ready quickaction
        let(:opts) { { wip_event: 'ready' } }

        it 'adds Duo as a reviewer' do
          update_merge_request(opts)

          expect(merge_request.reviewers).to eq [duo]
        end
      end

      context 'when it becomes ready by title change' do
        let(:opts) { { title: 'Awesome merge_request' } }

        it 'adds Duo as a reviewer' do
          update_merge_request(opts)

          expect(merge_request.reviewers).to eq [duo]
        end

        context 'when another reviewer exists' do
          before do
            merge_request.reviewers = [user]
          end

          it 'adds Duo as a reviewer' do
            update_merge_request(opts)

            expect(merge_request.reviewers).to match_array [user, duo]
          end
        end

        context 'when Duo Code Review feature is not allowed' do
          let(:ai_review_allowed) { false }

          it 'does not add Duo as a reviewer' do
            update_merge_request(opts)

            expect(merge_request.reviewers).to be_empty
          end
        end

        context 'when Auto Duo Code Review project setting is disabled' do
          let(:auto_duo_code_review) { false }

          it 'does not add Duo as a reviewer' do
            update_merge_request(opts)

            expect(merge_request.reviewers).to be_empty
          end
        end
      end

      context 'when project setting disable duo' do
        let(:duo_enabled_project_setting) { false }

        it 'does not add Duo as a reviewer' do
          update_merge_request({ title: 'Awesome merge_request' })

          expect(merge_request.reviewers).to be_empty
        end
      end

      context 'duo enterprise add on expired' do
        before do
          project.namespace.subscription_add_on_purchases.for_duo_enterprise.update!(expires_on: 1.day.ago)
        end

        it 'does not add Duo as a reviewer' do
          update_merge_request({ title: 'Awesome merge_request' })

          expect(merge_request.reviewers).to be_empty
        end
      end

      context 'when it becomes draft' do
        let(:old_title) { 'Awesome merge_request' }
        let(:opts) { { title: 'Draft: Awesome merge_request' } }

        it 'does not add Duo as a reviewer' do
          update_merge_request(opts)

          expect(merge_request.reviewers).to be_empty
        end
      end

      context 'when title is not being changed' do
        let(:opts) { { description: 'This is awesome' } }

        it 'does not add Duo as a reviewer' do
          update_merge_request(opts)

          expect(merge_request.reviewers).to be_empty
        end
      end
    end

    describe 'when v2_approval_rules flag is enabled' do
      let!(:existing_v1_any_rule) { create(:any_approver_rule, merge_request: merge_request) }
      let!(:existing_v1_rule) { create(:approval_merge_request_rule, merge_request: merge_request, name: 'rule 1') }
      let!(:existing_v2_any_rule) do
        create(
          :merge_requests_approval_rule,
          merge_request: merge_request,
          origin: :merge_request,
          project_id: project.id,
          rule_type: :any_approver
        )
      end

      let!(:existing_v2_rule) do
        create(
          :merge_requests_approval_rule,
          merge_request: merge_request,
          origin: :merge_request,
          project_id: project.id,
          name: 'rule 1')
      end

      let(:v1_rules) { merge_request.reload.approval_rules }
      let(:v2_rules) { merge_request.reload.v2_approval_rules }

      let(:opts) { { approval_rules_attributes: approval_rules_attributes } }
      let(:execute) { update_merge_request(opts) }

      before do
        stub_feature_flags(v2_approval_rules: true)
      end

      context 'when approval rules can be overridden' do
        before do
          merge_request.project.update!(disable_overriding_approvers_per_merge_request: false)
        end

        context 'approval_rules_attributes _destroy param is set' do
          let(:approval_rules_attributes) { [id: existing_v2_rule.id, _destroy: 1] }

          it 'deletes existing v1 and v2 approval rules' do
            expect { execute }.to change { v1_rules.count }.from(2).to(1).and change { v2_rules.count }.from(2).to(1)
          end
        end

        context 'new approval_rules_attribute is provided' do
          let(:approval_rules_attributes) { [{ name: 'New Rule', approvals_required: 1 }] }

          it 'creates a new v1 and v2 rule' do
            execute

            expect(v1_rules.size).to eq(3)
            expect(v2_rules.size).to eq(3)
            expect(v1_rules.last.name).to eq('New Rule')
            expect(v2_rules.last.name).to eq('New Rule')
          end
        end

        context 'approval_rule name updated' do
          let(:approval_rules_attributes) { [{ id: existing_v2_rule.id, name: "updated name" }] }

          it 'updates the name of the v1 and v2 rule' do
            execute

            expect(existing_v1_rule.reload.name).to eq('updated name')
            expect(existing_v2_rule.reload.name).to eq('updated name')
          end
        end
      end
    end
  end
end
