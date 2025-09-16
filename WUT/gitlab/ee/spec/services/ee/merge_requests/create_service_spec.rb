# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::CreateService, feature_category: :code_review_workflow do
  include ProjectForksHelper

  let(:project) { create(:project, :repository) }
  let(:service) { described_class.new(project: project, current_user: user, params: opts) }
  let(:opts) do
    {
      title: 'Awesome merge_request',
      description: 'please fix',
      source_branch: 'feature',
      target_branch: 'master',
      force_remove_source_branch: '1'
    }
  end

  before do
    allow(service).to receive(:execute_hooks)
  end

  describe '#execute' do
    let(:user) { create(:user) }

    before do
      project.add_maintainer(user)
    end

    it 'temporarily unapproves the MR' do
      mr = service.execute

      expect(mr.temporarily_unapproved?).to be_truthy
    end

    it 'passes the expire_unapproved_key param to the SyncCodeOwner worker' do
      expect(::MergeRequests::SyncCodeOwnerApprovalRulesWorker).to receive(:perform_async)
        .with(kind_of(Integer), expire_unapproved_key: true)

      service.execute
    end

    it 'schedules refresh of code owners for the merge request' do
      Sidekiq::Testing.fake! do
        expect { service.execute }.to change(::MergeRequests::SyncCodeOwnerApprovalRulesWorker.jobs, :size).by(1)
        ::MergeRequests::SyncCodeOwnerApprovalRulesWorker.clear
      end
    end

    context 'report approvers' do
      it 'refreshes report approvers for the merge request' do
        expect_next_instance_of(::MergeRequests::SyncReportApproverApprovalRules) do |service|
          expect(service).to receive(:execute)
        end

        service.execute
      end
    end

    it_behaves_like 'new issuable with scoped labels' do
      let(:parent) { project }
      let(:service_result) { described_class.new(**args).execute }
      let(:issuable) { service_result }
    end

    it_behaves_like 'service with multiple reviewers' do
      let(:execute) { service.execute }
    end

    it_behaves_like 'service with approval rules' do
      let(:execute) { service.execute }
    end

    it 'sends the audit streaming event' do
      audit_context = {
        name: 'merge_request_create',
        stream_only: true,
        author: user,
        scope: project,
        message: 'Added merge request'
      }

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(audit_context))

      service.execute
    end

    describe 'Automatic Duo Code Review' do
      let(:ai_review_allowed) { true }
      let(:auto_duo_code_review) { true }
      let(:duo_enabled_project_setting) { true }
      let(:duo) { ::Users::Internal.duo_code_review_bot }
      let(:created_merge_request) { service.execute }
      let(:duo_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

      before do
        allow(project).to receive(:auto_duo_code_review_enabled).and_return(auto_duo_code_review)
        allow(project.project_setting).to receive(:duo_features_enabled?).and_return(duo_enabled_project_setting)

        create(:gitlab_subscription_add_on_purchase,
          namespace: project.namespace,
          add_on: duo_add_on)

        allow_next_instance_of(MergeRequest) do |merge_request|
          allow(merge_request).to receive(:ai_review_merge_request_allowed?)
            .with(user)
            .and_return(ai_review_allowed)
        end
      end

      it 'adds Duo as a reviewer' do
        expect(created_merge_request.reviewers).to eq [duo]
      end

      context 'when another reviewer exists' do
        let(:opts) do
          super().merge(reviewer_ids: [user.id])
        end

        it 'adds Duo as a reviewer' do
          expect(created_merge_request.reviewers).to match_array [user, duo]
        end
      end

      context 'when Duo Code Review feature is not allowed' do
        let(:ai_review_allowed) { false }

        it 'does not add Duo as a reviewer' do
          expect(created_merge_request.reviewers).to be_empty
        end
      end

      context 'when the MR is draft' do
        let(:opts) do
          super().merge(title: 'Draft: Awesome merge_request')
        end

        it 'does not add Duo as a reviewer' do
          expect(created_merge_request.reviewers).to be_empty
        end
      end

      context 'when Auto Duo Code Review project setting is disabled' do
        let(:auto_duo_code_review) { false }

        it 'does not add Duo as a reviewer' do
          expect(created_merge_request.reviewers).to be_empty
        end
      end

      context 'when project setting disable duo' do
        let(:duo_enabled_project_setting) { false }

        it 'does not add Duo as a reviewer' do
          expect(created_merge_request.reviewers).to be_empty
        end
      end

      context 'duo enterprise add on expired' do
        before do
          project.namespace.subscription_add_on_purchases.for_duo_enterprise.update!(expires_on: 1.day.ago)
        end

        it 'does not add Duo as a reviewer' do
          expect(created_merge_request.reviewers).to be_empty
        end
      end
    end
  end

  describe '#execute with blocking merge requests', :clean_gitlab_redis_shared_state do
    let(:opts) { { title: 'Blocked MR', source_branch: 'feature', target_branch: 'master' } }
    let(:user) { project.first_owner }

    it 'delegates to MergeRequests::UpdateBlocksService' do
      expect(MergeRequests::UpdateBlocksService)
        .to receive(:extract_params!)
        .and_return(:extracted_params)

      expect_next_instance_of(MergeRequests::UpdateBlocksService) do |block_service|
        expect(block_service.merge_request.title).to eq('Blocked MR')
        expect(block_service.current_user).to eq(user)
        expect(block_service.params).to eq(:extracted_params)

        expect(block_service).to receive(:execute)
      end

      service.execute
    end
  end
end
