# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::AfterCreateService, feature_category: :code_review_workflow do
  let_it_be(:merge_request) { create(:merge_request) }
  let_it_be(:project) { merge_request.target_project }

  let(:service_object) { described_class.new(project: project, current_user: merge_request.author) }

  describe '#execute' do
    subject(:execute) { service_object.execute(merge_request) }

    before do
      allow(::MergeRequests::NotifyApproversWorker).to receive(:perform_in)
    end

    it 'schedules approval notifications' do
      execute

      expect(::MergeRequests::NotifyApproversWorker).to have_received(:perform_in).with(10.seconds, merge_request.id)
    end

    it 'publishes created event' do
      expect { execute }
        .to publish_event(::MergeRequests::CreatedEvent).with(
          merge_request_id: merge_request.id
        )
    end

    it_behaves_like 'records an onboarding progress action', :merge_request_created do
      let(:namespace) { merge_request.target_project.namespace }
    end

    describe 'policy synchronization' do
      it_behaves_like 'synchronizes policies for a merge request'
    end

    it_behaves_like 'audits security policy branch bypass'

    describe 'suggested reviewers' do
      before do
        allow(MergeRequests::FetchSuggestedReviewersWorker).to receive(:perform_async)
        allow(merge_request).to receive(:ensure_merge_request_diff)
      end

      context 'when suggested reviewers is available for project' do
        before do
          allow(project).to receive(:can_suggest_reviewers?).and_return(true)
        end

        context 'when merge request can suggest reviewers' do
          before do
            allow(merge_request).to receive(:can_suggest_reviewers?).and_return(true)
          end

          it 'calls fetch worker for the merge request' do
            execute

            expect(merge_request).to have_received(:ensure_merge_request_diff).ordered
            expect(MergeRequests::FetchSuggestedReviewersWorker).to have_received(:perform_async)
              .with(merge_request.id)
              .ordered
          end
        end

        context 'when merge request cannot suggest reviewers' do
          before do
            allow(merge_request).to receive(:can_suggest_reviewers?).and_return(false)
          end

          it 'does not call fetch worker for the merge request' do
            execute

            expect(MergeRequests::FetchSuggestedReviewersWorker).not_to have_received(:perform_async)
          end
        end
      end

      context 'when suggested reviewers is not available for project' do
        before do
          allow(project).to receive(:can_suggest_reviewers?).and_return(false)
        end

        context 'when merge request can suggest reviewers' do
          before do
            allow(merge_request).to receive(:can_suggest_reviewers?).and_return(true)
          end

          it 'does not call fetch worker for the merge request' do
            execute

            expect(MergeRequests::FetchSuggestedReviewersWorker).not_to have_received(:perform_async)
          end
        end
      end
    end

    describe 'schedule_duo_code_review' do
      let(:merge_request) { create(:merge_request) }
      let(:current_user) { merge_request.author }
      let(:ai_review_allowed) { true }

      before do
        allow(merge_request).to receive(:ai_review_merge_request_allowed?)
          .with(current_user)
          .and_return(ai_review_allowed)
      end

      context 'when Duo Code Review bot is not assigned as a reviewer' do
        it 'does not call ::Llm::ReviewMergeRequestService' do
          expect(Llm::ReviewMergeRequestService).not_to receive(:new)

          execute
        end
      end

      context 'when Duo Code Review bot is assigned as a reviewer' do
        let(:duo_user_id) { 1234 }

        before do
          merge_request.reviewers = [::Users::Internal.duo_code_review_bot]
        end

        context 'when AI review feature is not allowed' do
          let(:ai_review_allowed) { false }

          it 'does not call ::Llm::ReviewMergeRequestService' do
            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            execute
          end
        end

        context 'when AI review feature is allowed' do
          let(:ai_review_allowed) { true }

          it 'calls ::Llm::ReviewMergeRequestService' do
            expect_next_instance_of(Llm::ReviewMergeRequestService, current_user, merge_request) do |svc|
              expect(svc).to receive(:execute)
            end

            execute
          end
        end
      end
    end

    describe 'usage activity tracking' do
      let(:user) { merge_request.author }
      let(:event_name) { 'users_creating_merge_requests_with_security_policies' }

      context 'when project has no security policy configuration' do
        it "doesn't count event users_creating_merge_requests_with_security_policies" do
          expect(Gitlab::UsageDataCounters::HLLRedisCounter).not_to receive(:track_event).with(event_name, any_args)

          execute
        end
      end

      context 'with project security_orchestration_policy_configuration' do
        before do
          configuration = create(:security_orchestration_policy_configuration, project: project)
          create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration, project: project)
        end

        it 'tracks users_creating_merge_requests_with_security_policies counter' do
          allow(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
          expect(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event).with(event_name, values: user.id)

          execute
        end
      end

      context "with group security_orchestration_policy_configuration" do
        let_it_be(:configuration) { create(:security_orchestration_policy_configuration, :namespace) }

        before do
          create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration, project: project)
          project.update!(namespace: configuration.namespace)
        end

        it 'tracks users_creating_merge_requests_with_security_policies counter' do
          allow(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
          expect(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event).with(event_name, values: user.id)

          execute
        end
      end
    end

    context 'for audit events' do
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }
      let_it_be(:merge_request) { create(:merge_request, author: project_bot) }

      include_examples 'audit event logging' do
        let(:operation) { execute }
        let(:event_type) { 'merge_request_created_by_project_bot' }
        let(:fail_condition!) { expect(project_bot).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: merge_request.target_project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: 'merge_request_created_by_project_bot',
              target_id: merge_request.id,
              target_type: 'MergeRequest',
              target_details: {
                iid: merge_request.iid,
                id: merge_request.id,
                source_branch: merge_request.source_branch,
                target_branch: merge_request.target_branch
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Created merge request #{merge_request.title}"
            }
          }
        end
      end
    end
  end
end
