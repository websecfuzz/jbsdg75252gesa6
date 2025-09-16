# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRulePolicy, feature_category: :source_code_management do
  let_it_be_with_refind(:project) { create(:project, :private) }
  let(:rule_type) { :regular }
  let(:guest) { create(:user) }
  let(:maintainer) { create(:user, maintainer_of: project) }

  let(:user) { guest }

  subject(:permissions) { described_class.new(user, approval_rule) }

  context 'when the rule originates from project' do
    let(:approval_rule) do
      build(:merge_requests_approval_rule, :from_project,
        project: project,
        project_id: project.id,
        rule_type: rule_type
      )
    end

    context 'and the user has permission to read the project' do
      let(:user) { maintainer }

      it { is_expected.to be_allowed(:read_approval_rule) }
    end

    context 'and the user has permission to change project settings' do
      let(:user) { maintainer }

      it { is_expected.to be_allowed(:edit_approval_rule) }
    end

    context 'and the user lacks the required access level' do
      it { is_expected.not_to be_allowed(:edit_approval_rule) }
      it { is_expected.not_to be_allowed(:read_approval_rule) }
    end
  end

  context 'when the rule originates from a merge request' do
    let(:merge_request) { create(:merge_request, source_project: project) }
    let(:approval_rule) do
      build(:merge_requests_approval_rule, :from_merge_request, merge_request: merge_request, project_id: project.id,
        rule_type: rule_type)
    end

    context 'and the ensure_consistent_editing_rule flag is enabled' do
      let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let(:user) { merge_request.author }

      before do
        project.update!(
          disable_overriding_approvers_per_merge_request: false,
          visibility_level: Gitlab::VisibilityLevel::PUBLIC
        )
      end

      context 'when the rule is editable' do
        before do
          allow(approval_rule).to receive(:editable_by_user?).and_return(true)
        end

        context 'when the merge request can be updated' do
          it { is_expected.to be_allowed(:edit_approval_rule) }
        end

        context 'when the merge request can not be updated' do
          before do
            project.project_feature.merge_requests_access_level = Featurable::DISABLED
            project.save!
          end

          it { is_expected.not_to be_allowed(:edit_approval_rule) }
        end
      end

      context 'when the rule is not editable' do
        it 'disallows updating approval rule' do
          expect(approval_rule).to receive(:editable_by_user?).and_return(false)

          expect(permissions).not_to be_allowed(:edit_approval_rule)
        end
      end
    end

    context 'and the ensure_consistent_editing_rule flag is not enabled' do
      before do
        stub_feature_flags(ensure_consistent_editing_rule: false)
      end

      context 'and the user has permission to read the merge request' do
        let(:user) { maintainer }

        it { is_expected.to be_allowed(:read_approval_rule) }
      end

      context 'and the user has permission to change merge request settings' do
        let(:user) { maintainer }

        it { is_expected.to be_allowed(:edit_approval_rule) }

        context 'and the approval rule is not user defined' do
          let(:rule_type) { :code_owner }

          it { is_expected.not_to be_allowed(:edit_approval_rule) }
        end
      end

      context 'and the user lacks the required access level' do
        it { is_expected.not_to be_allowed(:edit_approval_rule) }
        it { is_expected.not_to be_allowed(:read_approval_rule) }
      end
    end
  end

  context 'when the rule originates from a group' do
    let(:approval_rule) do
      build(:merge_requests_approval_rule, :from_group,
        project: project,
        project_id: project.id,
        rule_type: rule_type
      )
    end

    # TODO: Update this once group approval rules have been implemented
    it { is_expected.not_to be_allowed(:edit_approval_rule) }
    it { is_expected.not_to be_allowed(:read_approval_rule) }
  end
end
