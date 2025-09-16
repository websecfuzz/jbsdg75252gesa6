# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalMergeRequestRulePolicy, feature_category: :source_code_management do
  def permissions(user, approval_rule)
    described_class.new(user, approval_rule)
  end

  shared_examples 'editing a merge request approval policy' do
    context 'when the rule is editable' do
      before do
        allow(approval_rule).to receive(:editable_by_user?).and_return(true)
      end

      context 'when the merge request can be updated' do
        it 'allows updating approval rule' do
          expect(permissions(user, approval_rule)).to be_allowed(:edit_approval_rule)
        end
      end

      context 'when the merge request can not be updated' do
        let!(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

        before do
          project.project_feature.merge_requests_access_level = Featurable::DISABLED
          project.save!
        end

        it 'disallows updating approval rule' do
          expect(permissions(user, approval_rule)).to be_disallowed(:edit_approval_rule)
        end
      end
    end

    context 'when the rule is not editable' do
      before do
        allow(approval_rule).to receive(:editable_by_user?).and_return(false)
      end

      it 'disallows updating approval rule' do
        expect(approval_rule).to receive(:editable_by_user?).and_return(false)

        expect(permissions(user, approval_rule)).to be_disallowed(:edit_approval_rule)
      end
    end
  end

  context 'when ensure_consistent_editing_rule is on' do
    let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
    let(:project) { create(:project, :public, disable_overriding_approvers_per_merge_request: false) }
    let(:user) { merge_request.author }

    let(:approval_rule) { create(:approval_merge_request_rule, merge_request: merge_request) }

    it_behaves_like 'editing a merge request approval policy'
  end

  context 'when ensure_consistent_editing_rule is off' do
    let_it_be(:merge_request) { create(:merge_request) }
    let_it_be(:approval_rule) { create(:approval_merge_request_rule, merge_request: merge_request) }

    before do
      stub_feature_flags(ensure_consistent_editing_rule: false)
    end

    context 'when user can update merge request' do
      it 'allows updating approval rule' do
        expect(permissions(merge_request.author, approval_rule)).to be_allowed(:edit_approval_rule)
      end

      context 'when rule is any-approval' do
        let(:approval_rule) { build(:any_approver_rule, merge_request: merge_request) }

        it 'allows updating approval rule' do
          expect(permissions(merge_request.author, approval_rule)).to be_allowed(:edit_approval_rule)
        end
      end

      context 'when rule is not user editable' do
        let(:approval_rule) { create(:code_owner_rule, merge_request: merge_request) }

        it 'disallows updating approval rule' do
          expect(permissions(merge_request.author, approval_rule)).to be_disallowed(:edit_approval_rule)
        end
      end
    end

    context 'when user cannot update merge request' do
      it 'disallows updating approval rule' do
        expect(permissions(create(:user), approval_rule)).to be_disallowed(:edit_approval_rule)
      end
    end
  end
end
