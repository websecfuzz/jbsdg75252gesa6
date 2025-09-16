# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestPolicy, :aggregate_failures, feature_category: :code_review_workflow do
  include ProjectForksHelper
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:guest) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let_it_be(:fork_guest) { create(:user) }
  let_it_be(:fork_developer) { create(:user) }
  let_it_be(:fork_maintainer) { create(:user) }

  let(:project) { create(:project, :internal) }

  let(:owner) { project.owner }
  let(:forked_project) { fork_project(project) }
  let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let(:fork_merge_request) { create(:merge_request, author: fork_developer, source_project: forked_project, target_project: project) }

  before do
    project.add_guest(guest)
    project.add_developer(developer)
    project.add_maintainer(maintainer)
    project.add_reporter(reporter)

    forked_project.add_guest(fork_guest)
    forked_project.add_developer(fork_developer)
    forked_project.add_maintainer(fork_maintainer)
  end

  def policy_for(user)
    described_class.new(user, merge_request)
  end

  context 'for a merge request within the same project' do
    context 'when overwriting approvers is disabled on the project' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it 'does not allow anyone to update approvers' do
        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(developer)).to be_disallowed(:update_approvers)
        expect(policy_for(maintainer)).to be_disallowed(:update_approvers)

        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end

    context 'when overwriting approvers is enabled on the project' do
      it 'allows only project developers and above to update the approvers' do
        expect(policy_for(developer)).to be_allowed(:update_approvers)
        expect(policy_for(maintainer)).to be_allowed(:update_approvers)

        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end
  end

  context 'for a merge request from a fork' do
    let(:merge_request) { fork_merge_request }

    context 'when overwriting approvers is disabled on the target project' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it 'does not allow anyone to update approvers' do
        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(developer)).to be_disallowed(:update_approvers)
        expect(policy_for(maintainer)).to be_disallowed(:update_approvers)

        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end

    context 'when overwriting approvers is disabled on the source project' do
      before do
        forked_project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it 'has no effect - project developers and above, as well as the author, can update the approvers' do
        expect(policy_for(developer)).to be_allowed(:update_approvers)
        expect(policy_for(maintainer)).to be_allowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_allowed(:update_approvers)

        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end

    context 'when overwriting approvers is enabled on the target project' do
      it 'allows project developers and above, as well as the author, to update the approvers' do
        expect(policy_for(developer)).to be_allowed(:update_approvers)
        expect(policy_for(maintainer)).to be_allowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_allowed(:update_approvers)

        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end

    context 'allows project developers and above' do
      it 'to approve the merge requests' do
        expect(policy_for(developer)).to be_allowed(:update_approvers)
        expect(policy_for(maintainer)).to be_allowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_allowed(:update_approvers)

        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end
  end

  context 'for a merge request on a protected branch' do
    let(:branch_name) { 'feature' }
    let_it_be(:user) { create :user }
    let(:protected_branch) { create(:protected_branch, project: project, name: branch_name) }
    let_it_be(:approver_group) { create(:group) }

    let(:merge_request) { create(:merge_request, source_project: project, target_project: project, target_branch: branch_name) }

    before do
      project.add_reporter(user)
    end

    subject { described_class.new(user, merge_request) }

    context 'when the reporter nor the group is added' do
      specify do
        expect(subject).not_to be_allowed(:approve_merge_request)
      end
    end

    context 'when a group-level approval rule exists' do
      let(:approval_project_rule) { create :approval_project_rule, project: project, approvals_required: 1 }

      context 'when the merge request targets the protected branch' do
        before do
          approval_project_rule.protected_branches << protected_branch
          approval_project_rule.groups << approver_group
        end

        context 'when the reporter is not a group member' do
          specify do
            expect(subject).not_to be_allowed(:approve_merge_request)
          end
        end

        context 'when the reporter is a group member' do
          before do
            approver_group.add_reporter(user)
          end

          specify do
            expect(subject).to be_allowed(:approve_merge_request)
          end
        end
      end

      context 'when the reporter has permission for a different protected branch' do
        let(:protected_branch2) { create(:protected_branch, project: project, name: branch_name, code_owner_approval_required: true) }

        before do
          approval_project_rule.protected_branches << protected_branch2
          approval_project_rule.groups << approver_group
        end

        it 'does not allow approval of the merge request' do
          expect(subject).not_to be_allowed(:approve_merge_request)
        end
      end

      context 'when the protected branch name is a wildcard' do
        let(:wildcard_protected_branch) { create(:protected_branch, project: project, name: '*-stable') }

        before do
          approval_project_rule.protected_branches << wildcard_protected_branch
          approval_project_rule.groups << approver_group
          approver_group.add_reporter(user)
        end

        context 'when the reporter has permission for the wildcarded branch' do
          let(:branch_name) { '13-4-stable' }

          it 'does allows approval of the merge request' do
            expect(subject).to be_allowed(:approve_merge_request)
          end
        end

        context 'when the reporter does not have permission for the wildcarded branch' do
          let(:branch_name) { '13-4-pre' }

          it 'does allows approval of the merge request' do
            expect(subject).not_to be_allowed(:approve_merge_request)
          end
        end
      end
    end
  end

  context 'when checking for namespace in read only state' do
    context 'when namespace is in a read only state' do
      before do
        allow(merge_request.target_project.namespace).to receive(:read_only?).and_return(true)
      end

      it 'does not allow update_merge_request for all users including maintainer' do
        expect(policy_for(maintainer)).to be_disallowed(:update_merge_request)
      end

      it 'does allow approval of the merge request' do
        expect(policy_for(developer)).to be_allowed(:approve_merge_request)
      end
    end

    context 'when namespace is not in a read only state' do
      before do
        allow(merge_request.target_project.namespace).to receive(:read_only?).and_return(false)
      end

      it 'does not lock basic policies for any user' do
        expect(policy_for(maintainer)).to be_allowed(
          :approve_merge_request,
          :update_merge_request,
          :reopen_merge_request,
          :create_note,
          :resolve_note
        )
      end
    end
  end

  shared_examples 'external_status_check_access' do
    using RSpec::Parameterized::TableSyntax

    subject { policy_for(current_user) }

    where(:role, :licensed, :allowed) do
      :guest      | false  | false
      :reporter   | false  | false
      :developer  | false  | false
      :maintainer | false  | false
      :owner      | false  | false
      :admin      | false  | false
      :guest      | true   | ref(:allowed_for_guest)
      :reporter   | true   | ref(:allowed_for_reporter)
      :developer  | true   | true
      :maintainer | true   | true
      :owner      | true   | true
      :admin      | true   | true
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        stub_licensed_features(external_status_checks: licensed)
        enable_admin_mode!(current_user) if role.eql?(:admin)
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe 'retry_failed_status_checks' do
    let(:policy) { :retry_failed_status_checks }
    let(:allowed_for_reporter) { false }
    let(:allowed_for_guest) { false }

    it_behaves_like 'external_status_check_access'
  end

  describe 'read_external_status_check_response' do
    let(:policy) { :read_external_status_check_response }
    let(:allowed_for_reporter) { true }

    context 'when project is internal' do
      let(:project) { create(:project, :internal) }

      context 'when user is external' do
        let(:allowed_for_guest) { false }

        before do
          current_user.update!(external: true)
        end

        it_behaves_like 'external_status_check_access'
      end

      context 'when user is internal' do
        let(:allowed_for_guest) { true }

        before do
          current_user.update!(external: false)
        end

        it_behaves_like 'external_status_check_access'
      end
    end

    context 'when project is private' do
      let(:project) { create(:project, :private) }
      let(:allowed_for_guest) { false }

      it_behaves_like 'external_status_check_access'
    end
  end

  describe 'provide_status_check_response' do
    let(:policy) { :provide_status_check_response }
    let(:allowed_for_reporter) { false }
    let(:allowed_for_guest) { false }

    it_behaves_like 'external_status_check_access'
  end

  describe 'create_merge_request_approval_rules' do
    using RSpec::Parameterized::TableSyntax

    let(:policy) { :create_merge_request_approval_rules }
    let(:current_user) { owner }

    subject { policy_for(current_user) }

    where(:coverage_license_enabled, :report_approver_license_enabled, :allowed) do
      false | false | false
      true  | true  | true
      false | true  | true
      true  | false | true
    end

    with_them do
      before do
        stub_licensed_features(
          coverage_check_approval_rule: coverage_license_enabled,
          report_approver_rules: report_approver_license_enabled
        )
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe "Custom roles `admin_merge_request` ability" do
    let_it_be(:project) { create(:project, :public, :in_group) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    subject { described_class.new(guest, merge_request) }

    context 'when the `custom_roles` feature is enabled' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'when the user is a member of a custom role with `admin_merge_request` enabled' do
        let_it_be(:custom_role) { create(:member_role, :guest, namespace: project.group, admin_merge_request: true) }
        let_it_be(:project_member) { create(:project_member, :guest, member_role: custom_role, project: project, user: guest) }

        it 'enables the `approve_merge_request` ability' do
          expect(subject).to be_allowed(:approve_merge_request)
        end
      end

      context 'when the user is a member of a custom role with `admin_merge_request` disabled' do
        let_it_be(:custom_role) { create(:member_role, :guest, namespace: project.group, admin_merge_request: false) }
        let_it_be(:project_member) { create(:project_member, :guest, member_role: custom_role, project: project, user: guest) }

        it 'disables the `approve_merge_request` ability' do
          expect(subject).to be_disallowed(:approve_merge_request)
        end
      end
    end

    context 'when the `custom_roles` feature is disabled' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'disables the `approve_merge_request` ability' do
        expect(subject).to be_disallowed(:approve_merge_request)
      end
    end
  end

  describe 'access_generate_commit_message' do
    let(:user) { owner }

    subject(:policy) { policy_for(user) }

    where(:duo_features_enabled, :allowed_to_use, :enabled_for_user) do
      true  | false | be_disallowed(:access_generate_commit_message)
      false | true  | be_disallowed(:access_generate_commit_message)
      true  | true  | be_allowed(:access_generate_commit_message)
    end

    with_them do
      before do
        allow(project)
          .to receive_message_chain(:project_setting, :duo_features_enabled?)
          .and_return(duo_features_enabled)

        allow(user).to receive(:allowed_to_use?)
          .with(:generate_commit_message, licensed_feature: :generate_commit_message).and_return(allowed_to_use)
      end

      it { is_expected.to enabled_for_user }
    end
  end

  describe 'access_summarize_review' do
    let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }
    let(:user) { can_read_mr ? reporter : nil }

    where(:duo_features_enabled, :feature_flag_enabled, :llm_authorized, :can_read_mr, :expected_result) do
      true  | true  | true  | true  | be_allowed(:access_summarize_review)
      true  | true  | true  | false | be_disallowed(:access_summarize_review)
      true  | false | true  | true  | be_disallowed(:access_summarize_review)
      true  | true  | false | true  | be_disallowed(:access_summarize_review)
      false | true  | true  | true  | be_disallowed(:access_summarize_review)
    end

    with_them do
      subject { policy_for(user) }

      before do
        # Setup Duo features
        allow(project)
          .to receive_message_chain(:project_setting, :duo_features_enabled?)
          .and_return(duo_features_enabled)

        # Setup feature flag
        stub_feature_flags(summarize_my_code_review: feature_flag_enabled)

        # Setup LLM authorizer
        allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
        allow(authorizer).to receive(:allowed?).and_return(llm_authorized)
      end

      it { is_expected.to expected_result }
    end
  end
end
