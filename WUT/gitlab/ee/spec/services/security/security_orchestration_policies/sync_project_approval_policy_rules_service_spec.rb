# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::SyncProjectApprovalPolicyRulesService, feature_category: :security_policy_management do
  let_it_be_with_refind(:group) { create(:group, :public) }
  let_it_be_with_refind(:project) { create(:project, :empty_repo, namespace: group) }
  let_it_be(:approver) { create(:user) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be_with_refind(:security_policy) do
    create(:security_policy, :require_approval, security_orchestration_policy_configuration: policy_configuration,
      linked_projects: [project])
  end

  let(:service) { described_class.new(project: project, security_policy: security_policy) }

  shared_examples 'calls sync_merge_requests' do
    it 'calls Security::SecurityOrchestrationPolicies::SyncMergeRequestsService' do
      expect(Security::SecurityOrchestrationPolicies::SyncMergeRequestsService).to receive(:new).with(
        project: project, security_policy: security_policy
      ).and_call_original

      action
    end
  end

  describe '#create_rules' do
    before_all do
      group.add_maintainer(approver)

      sha = project.repository.create_file(
        project.creator,
        "README.md",
        "",
        message: "initial commit",
        branch_name: 'master')

      create(:protected_branch, name: 'master', project: project)
      project.repository.add_branch(project.creator, 'master', sha)
    end

    before do
      allow(project).to receive(:multiple_approval_rules_available?).and_return(true)
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
        allow(configuration).to receive(:policy_last_updated_by).and_return(approver)
      end
    end

    subject(:create_rules) { service.create_rules }

    shared_examples 'create approval rule with specific approver' do
      it 'succeeds creating approval rules with specific approver' do
        expect { create_rules }.to change { project.approval_rules.count }.by(1)
        expect(project.approval_rules.first.approvers).to contain_exactly(approver)
      end
    end

    it_behaves_like 'calls sync_merge_requests' do
      let(:action) { create_rules }
    end

    it 'calls Security::ScanResultPolicies::ApprovalRules::CreateService' do
      expect(Security::ScanResultPolicies::ApprovalRules::CreateService).to receive(:new).with(
        project: project,
        security_policy: security_policy,
        approval_policy_rules: security_policy.approval_policy_rules.undeleted,
        author: approver
      ).and_call_original

      create_rules
    end

    context 'with empty actions' do
      let_it_be(:approval_policy_rule) do
        create(:approval_policy_rule, :any_merge_request, security_policy: security_policy)
      end

      before do
        security_policy.update!(content: { actions: [] })
      end

      it 'does not create approval rules' do
        expect { create_rules }.not_to change { project.approval_rules.count }
      end
    end

    context 'without approval_policy_rules' do
      it 'does not create approval project rules' do
        expect { create_rules }.not_to change { project.approval_rules.count }
      end
    end

    context 'without require_approval action' do
      let_it_be(:approval_policy_rule) do
        create(:approval_policy_rule, :any_merge_request, security_policy: security_policy)
      end

      before do
        security_policy.update!(content: { actions: [{ type: 'send_bot_message', enabled: true }] })
      end

      it 'does not create approval rules' do
        expect { create_rules }.not_to change { project.approval_rules.count }
      end
    end

    context 'with require_approval action' do
      let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

      context 'with only user id' do
        before do
          security_policy.update!(content: { actions: [{ type: 'require_approval', approvals_required: 1,
                                                         user_approvers_ids: [approver.id] }] })
        end

        it_behaves_like 'create approval rule with specific approver'
      end

      context 'with only username' do
        before do
          security_policy.update!(content: { actions: [{ type: 'require_approval', approvals_required: 1,
                                                         user_approvers: [approver.username] }] })
        end

        it_behaves_like 'create approval rule with specific approver'
      end

      context 'with role_approvers' do
        let_it_be(:custom_role) { create(:member_role, namespace: project.group) }
        let_it_be(:developer) { create(:user) }

        before do
          security_policy.update!(
            content: {
              actions: [{
                type: 'require_approval',
                approvals_required: 1,
                user_approvers: [approver.username],
                role_approvers: ['developer', custom_role.id]
              }]
            }
          )

          project.add_developer(developer) # rubocop:disable RSpec/BeforeAllRoleAssignment -- Does not work in before_all
        end

        it 'creates approval rules with role approvers' do
          expect { create_rules }.to change { project.approval_rules.count }.by(1)
          expect(project.approval_rules.first.approvers).to contain_exactly(approver, developer)
        end

        it 'creates scan_result_policy_read' do
          expect { create_rules }.to change { Security::ScanResultPolicyRead.count }.by(1)

          scan_result_policy_read = project.scan_result_policy_reads.first
          expect(scan_result_policy_read.custom_roles).to match_array([custom_role.id])
          expect(scan_result_policy_read.role_approvers).to match_array([Gitlab::Access::DEVELOPER])
          expect(scan_result_policy_read.approval_policy_rule_id).to be(approval_policy_rule.id)
        end
      end

      context 'with only group id' do
        before do
          security_policy.update!(
            content: { actions: [{ type: 'require_approval', approvals_required: 1, group_approvers_ids: [group.id] }] }
          )
        end

        it_behaves_like 'create approval rule with specific approver'

        context 'with public group outside of the scope' do
          let(:another_group) { create(:group, :public) }

          before do
            security_policy.update!(
              content: { actions: [{ type: 'require_approval', approvals_required: 1,
                                     group_approvers_ids: [another_group.id] }] }
            )
          end

          it 'does not include any approvers' do
            create_rules

            expect(project.approval_rules.first.approvers).to be_empty
          end
        end

        context 'with private group outside of the scope' do
          let(:another_group) { create(:group, :private) }

          before do
            security_policy.update!(
              content: { actions: [{ type: 'require_approval', approvals_required: 1,
                                     group_approvers_ids: [another_group.id] }] }
            )
          end

          it 'does not include any approvers' do
            create_rules

            expect(project.approval_rules.first.approvers).to be_empty
          end
        end

        context 'with an invited group' do
          let(:group_user) { create(:user) }
          let(:another_group) { create(:group, :public) }

          before do
            security_policy.update!(
              content: { actions: [{ type: 'require_approval', approvals_required: 1,
                                     group_approvers_ids: [another_group.id] }] }
            )
            another_group.add_maintainer(group_user)
            project.invited_groups = [another_group]
          end

          it 'includes group related approvers' do
            create_rules

            expect(project.approval_rules.first.approvers).to match_array([group_user])
          end
        end
      end

      context 'with only group path' do
        before do
          security_policy.update!(
            content: { actions: [{ type: 'require_approval', approvals_required: 1, group_approvers: [group.path] }] }
          )
        end

        it_behaves_like 'create approval rule with specific approver'

        context 'when groups with same name exist in and outside of container' do
          let(:other_container) { create(:group) }
          let(:other_group) { create(:group, name: group.name, parent: other_container) }
          let(:other_user) { create(:user) }

          before do
            security_policy.update!(
              content: { actions: [{ type: 'require_approval', approvals_required: 1, group_approvers: [group.name] }] }
            )
            other_group.add_developer(other_user)
          end

          context 'with security_policy_global_group_approvers_enabled setting disabled' do
            before do
              stub_ee_application_setting(security_policy_global_group_approvers_enabled: false)
            end

            it 'excludes groups outside the container' do
              create_rules

              expect(project.approval_rules.first.approvers).not_to include(other_user)
            end
          end

          context 'with security_policy_global_group_approvers_enabled setting enabled' do
            before do
              stub_ee_application_setting(security_policy_global_group_approvers_enabled: true)
            end

            it 'includes groups outside the container' do
              create_rules

              expect(project.approval_rules.first.approvers).to include(other_user)
            end
          end
        end
      end
    end

    context 'with vulnerability_attributes and vulnerability_age' do
      let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }
      let(:vulnerability_attributes) do
        {
          false_positive: true,
          fix_available: false
        }
      end

      let(:vulnerability_age) { { operator: 'greater_than', interval: 'day', value: 1 } }

      before do
        content = approval_policy_rule.content.deep_symbolize_keys
        content[:vulnerability_attributes] = vulnerability_attributes
        content[:vulnerability_age] = vulnerability_age
        approval_policy_rule.update!(content: content)
      end

      it 'creates approval rule and ScanResultPolicyRead' do
        expect { create_rules }.to change { project.approval_rules.count }.by(1)

        approval_rule = project.approval_rules.last
        scan_result_policy_read = approval_rule.scan_result_policy_read

        expect(approval_rule.vulnerability_attributes).to eq({
          'false_positive' => true,
          'fix_available' => false
        })
        expect(scan_result_policy_read.vulnerability_attributes).to eq({
          'false_positive' => true,
          'fix_available' => false
        })
        expect(scan_result_policy_read.greater_than?).to be_truthy
        expect(scan_result_policy_read.day?).to be_truthy
        expect(scan_result_policy_read.age_value).to eq(1)
      end
    end

    context 'with empty branches' do
      let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

      before do
        create(:protected_branch, project: project)
      end

      it 'sets applies_to_all_protected_branches to true' do
        create_rules

        expect(project.approval_rules.first.applies_to_all_protected_branches).to be_truthy
        expect(project.approval_rules.first.applies_to_branch?('random-branch')).to be_falsey
      end
    end

    context 'with protected branch_type' do
      let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

      before do
        content = approval_policy_rule.content.deep_symbolize_keys
        content.delete(:branches)
        content[:branch_type] = 'protected'
        approval_policy_rule.update!(content: content)
      end

      it 'sets applies_to_all_protected_branches to true' do
        create_rules

        expect(project.approval_rules.first.applies_to_all_protected_branches).to be_truthy
        expect(project.approval_rules.first.applies_to_branch?('random-branch')).to be_falsey
      end
    end

    context 'with branch exceptions' do
      let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

      before do
        content = approval_policy_rule.content.deep_symbolize_keys
        content.delete(:branches)
        content[:branch_type] = 'protected'
        content[:branch_exceptions] = ['main']
        approval_policy_rule.update!(content: content)
      end

      it 'sets applies_to_all_protected_branches to false' do
        create_rules

        expect(project.approval_rules.first.applies_to_all_protected_branches).to be_falsey
        expect(project.approval_rules.first.applies_to_branch?('main')).to be_falsey
      end
    end

    context 'with approval_settings' do
      let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

      let(:approval_settings) do
        {
          prevent_approval_by_author: true,
          prevent_approval_by_commit_author: true,
          remove_approvals_with_new_commit: true,
          require_password_to_approve: true,
          block_branch_modification: true,
          prevent_pushing_and_force_pushing: true
        }
      end

      before do
        content = security_policy.content.deep_symbolize_keys
        content[:approval_settings] = approval_settings
        security_policy.update!(content: content)
      end

      it 'creates new approval rules and scan_result_policy_read' do
        expect { create_rules }.to change { project.approval_rules.count }.by(1)

        scan_result_policy_read = project.approval_rules.first.scan_result_policy_read
        expect(scan_result_policy_read.project_approval_settings).to eq(approval_settings.with_indifferent_access)
      end
    end

    context 'with send_bot_message action' do
      let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

      before do
        security_policy.update!(content: {
          actions: [
            { type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] },
            { type: 'send_bot_message', enabled: false }
          ]
        })
      end

      it 'creates scan_result_policy_read with send_bot_message data' do
        create_rules

        scan_result_policy_read = project.approval_rules.first.scan_result_policy_read
        expect(scan_result_policy_read.send_bot_message).to(eq('enabled' => false))
      end
    end

    context 'with fallback_behavior' do
      let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

      before do
        content = security_policy.content.deep_symbolize_keys
        content[:fallback_behavior] = { fail: "open" }
        security_policy.update!(content: content)
      end

      it 'sets fallback_behavior' do
        create_rules

        scan_result_policy_read = project.approval_rules.first.scan_result_policy_read

        expect(scan_result_policy_read.fallback_behavior).to eq("fail" => "open")
      end
    end

    context 'with license_finding rule_type' do
      shared_examples_for 'creates approval_rules with valid params' do
        it 'creates approval_rules with valid params' do
          create_rules

          approval_rule = project.approval_rules.first

          expect(approval_rule.severity_levels).to be_empty
        end
      end

      context 'when approval_policy_rule does not contains the license_types attribute' do
        let_it_be(:approval_policy_rule) do
          create(:approval_policy_rule, :license_finding_with_allowed_licenses, security_policy: security_policy)
        end

        it 'creates scan_result_policy_read' do
          create_rules

          scan_result_policy_read = project.approval_rules.first.scan_result_policy_read
          expect(scan_result_policy_read).to eq(Security::ScanResultPolicyRead.first)
          expect(scan_result_policy_read.licenses).to be_present
          expect(scan_result_policy_read.license_states).to match_array(%w[newly_detected detected])
          expect(scan_result_policy_read.rule_idx).to be(approval_policy_rule.rule_index)
        end

        it 'does not creates software_license_policies' do
          expect { create_rules }.not_to change { project.software_license_policies.count }
        end

        it_behaves_like 'creates approval_rules with valid params'
      end

      context 'when approval_policy_rule contains the license_types attribute' do
        let_it_be(:approval_policy_rule) do
          create(:approval_policy_rule, :license_finding, security_policy: security_policy)
        end

        it 'creates scan_result_policy_read' do
          create_rules

          scan_result_policy_read = project.approval_rules.first.scan_result_policy_read
          expect(scan_result_policy_read).to eq(Security::ScanResultPolicyRead.first)
          expect(scan_result_policy_read.match_on_inclusion_license).to be_truthy
          expect(scan_result_policy_read.license_states).to match_array(%w[newly_detected detected])
          expect(scan_result_policy_read.rule_idx).to be(approval_policy_rule.rule_index)
        end

        it 'creates software_license_policies' do
          expect { create_rules }.to change { project.software_license_policies.count }.by(2)
        end

        it_behaves_like 'creates approval_rules with valid params'
      end
    end

    context 'with any_merge_request rule_type' do
      let_it_be(:approval_policy_rule) do
        create(:approval_policy_rule, :any_merge_request,
          security_policy: security_policy,
          content: {
            type: 'any_merge_request',
            branches: [],
            commits: 'unsigned'
          }
        )
      end

      it 'creates new approval rules with provided params' do
        expect { create_rules }.to change { project.approval_rules.count }.by(1)

        approval_rule = project.approval_rules.first
        scan_result_policy_read = project.approval_rules.first.scan_result_policy_read

        expect(approval_rule).to be_any_merge_request
        expect(scan_result_policy_read).to eq(Security::ScanResultPolicyRead.first)
        expect(scan_result_policy_read).to be_commits_unsigned
        expect(scan_result_policy_read.rule_idx).to be(approval_policy_rule.rule_index)
      end
    end

    context 'with multiple require_approval actions' do
      let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

      let_it_be(:developer) { create(:user) }

      before do
        security_policy.update!(
          content: {
            actions: [
              { type: 'require_approval', approvals_required: 1, user_approvers: [approver.username] },
              { type: 'require_approval', approvals_required: 1, role_approvers: ['developer'] }
            ]
          }
        )

        project.add_developer(developer) # rubocop:disable RSpec/BeforeAllRoleAssignment -- Does not work in before_all
      end

      it_behaves_like 'calls sync_merge_requests' do
        let(:action) { create_rules }
      end

      it 'creates multiple approval rules for multiple actions', :aggregate_failures do
        expect { create_rules }.to change { project.approval_rules.count }.by(2)

        first_approval_rule = project.approval_rules.first
        second_approval_rule = project.approval_rules.last

        expect(first_approval_rule.approvers).to contain_exactly(approver)
        expect(second_approval_rule.approvers).to contain_exactly(developer)
        expect(first_approval_rule.approval_policy_action_idx).to eq(0)
        expect(second_approval_rule.approval_policy_action_idx).to eq(1)
      end

      it 'creates scan_result_policy_reads with action_idx' do
        expect { create_rules }.to change { project.scan_result_policy_reads.count }.by(2)

        expect(project.scan_result_policy_reads.map(&:action_idx)).to contain_exactly(0, 1)
      end
    end
  end

  describe '#delete_rules' do
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }
    let_it_be(:other_approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

    let_it_be(:project_approval_rule) do
      create(:approval_project_rule, :scan_finding,
        project: project,
        approval_policy_rule: approval_policy_rule,
        security_orchestration_policy_configuration: policy_configuration
      )
    end

    let_it_be(:other_project_approval_rule) do
      create(:approval_project_rule, :scan_finding,
        project: create(:project),
        security_orchestration_policy_configuration: policy_configuration
      )
    end

    subject(:delete_rules) { service.delete_rules }

    it 'deletes approval rules linked to project' do
      expect { delete_rules }.to change { project.approval_rules.count }.by(-1)
    end

    it 'calls Security::ScanResultPolicies::ApprovalRules::DeleteService' do
      expect(Security::ScanResultPolicies::ApprovalRules::DeleteService).to receive(:new).with(
        project: project,
        security_policy: security_policy,
        approval_policy_rules: security_policy.approval_policy_rules
      ).and_call_original

      delete_rules
    end

    it 'schedules DeleteApprovalPolicyRulesWorker when rules are not linked to projects' do
      expect(Security::DeleteApprovalPolicyRulesWorker).to receive(:perform_in)
        .with(1.minute, [approval_policy_rule.id, other_approval_policy_rule.id])

      delete_rules
    end

    context 'when rules are linked to projects' do
      before do
        create(:approval_policy_rule_project_link, approval_policy_rule: approval_policy_rule, project: project)
      end

      it 'does not schedule DeleteApprovalPolicyRulesWorker' do
        expect(Security::DeleteApprovalPolicyRulesWorker).not_to receive(:perform_in)

        delete_rules
      end
    end

    it_behaves_like 'calls sync_merge_requests' do
      let(:action) { delete_rules }
    end
  end

  describe '#update_rules' do
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }
    let_it_be(:scan_result_policy_read) do
      create(:scan_result_policy_read,
        project: project,
        security_orchestration_policy_configuration: policy_configuration,
        orchestration_policy_idx: security_policy.policy_index,
        rule_idx: approval_policy_rule.rule_index,
        approval_policy_rule_id: approval_policy_rule.id
      )
    end

    let_it_be(:project_approval_rule) do
      create(:approval_project_rule, :scan_finding,
        project: project,
        approval_policy_rule: approval_policy_rule,
        scan_result_policy_read: scan_result_policy_read,
        security_orchestration_policy_configuration: policy_configuration
      )
    end

    before do
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
        allow(configuration).to receive(:policy_last_updated_by).and_return(approver)
      end
    end

    subject(:update_rules) { service.update_rules }

    it 'calls Security::ScanResultPolicies::ApprovalRules::UpdateService' do
      expect(Security::ScanResultPolicies::ApprovalRules::UpdateService).to receive(:new).with(
        project: project,
        security_policy: security_policy,
        approval_policy_rules: security_policy.approval_policy_rules.undeleted,
        author: approver
      ).and_call_original

      update_rules
    end

    context 'with scan_finding rule changes' do
      let(:vulnerability_attributes) do
        {
          false_positive: true,
          fix_available: false
        }
      end

      let(:vulnerability_age) { { operator: 'greater_than', interval: 'day', value: 1 } }

      before do
        content = approval_policy_rule.content.deep_symbolize_keys
        content[:vulnerability_attributes] = vulnerability_attributes
        content[:vulnerability_age] = vulnerability_age
        approval_policy_rule.update!(content: content)
      end

      it 'updates approval rule and ScanResultPolicyRead' do
        update_rules

        expect(project_approval_rule.reload.vulnerability_attributes).to eq({
          'false_positive' => true,
          'fix_available' => false
        })
        expect(scan_result_policy_read.reload.vulnerability_attributes).to eq({
          'false_positive' => true,
          'fix_available' => false
        })
        expect(scan_result_policy_read.greater_than?).to be_truthy
        expect(scan_result_policy_read.day?).to be_truthy
        expect(scan_result_policy_read.age_value).to eq(1)
        expect(scan_result_policy_read.approval_policy_rule_id).to be(approval_policy_rule.id)
      end
    end

    context 'with action changes' do
      let(:group_user) { create(:user) }
      let(:another_group) { create(:group, :public) }

      before do
        security_policy.update!(
          content: {
            actions: [
              { type: 'require_approval', approvals_required: 1, group_approvers_ids: [another_group.id] },
              { type: 'send_bot_message', enabled: true }
            ]
          }
        )
        another_group.add_maintainer(group_user)
        project.invited_groups = [another_group]
      end

      it 'updates approval rule and ScanResultPolicyRead' do
        update_rules

        expect(project_approval_rule.reload.approvers).to match_array([group_user])
        expect(scan_result_policy_read.reload.send_bot_message).to(eq('enabled' => true))
      end
    end

    context 'with license changes' do
      before do
        approval_policy_rule.update!(
          type: Security::ApprovalPolicyRule.types[:license_finding],
          content: {
            type: 'license_finding',
            branches: [],
            match_on_inclusion_license: true,
            license_types: %w[BSD MIT],
            license_states: %w[newly_detected detected]
          }
        )
      end

      it 'updates ScanResultPolicyRead and software_license_policies' do
        update_rules

        expect(project_approval_rule.reload.severity_levels).to be_empty
        expect(project.software_license_policies.count).to eq(2)
        expect(project.software_license_policies.map(&:name)).to include('BSD', 'MIT')
        expect(scan_result_policy_read.reload.match_on_inclusion_license).to be_truthy
        expect(scan_result_policy_read.license_states).to match_array(%w[newly_detected detected])
        expect(scan_result_policy_read.rule_idx).to be(approval_policy_rule.rule_index)
        expect(scan_result_policy_read.approval_policy_rule_id).to be(approval_policy_rule.id)
      end
    end

    context 'with multiple require_approval actions' do
      let_it_be(:scan_result_policy_read_2) do
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: policy_configuration,
          orchestration_policy_idx: security_policy.policy_index,
          approval_policy_rule_id: approval_policy_rule.id,
          rule_idx: approval_policy_rule.rule_index,
          action_idx: 1
        )
      end

      let_it_be(:project_approval_rule_2) do
        create(:approval_project_rule, :scan_finding,
          project: project,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: scan_result_policy_read,
          security_orchestration_policy_configuration: policy_configuration,
          approval_policy_action_idx: 1
        )
      end

      let_it_be(:maintainer) { create(:user) }
      let_it_be(:approver) { create(:user) }

      before_all do
        security_policy.update!(
          content: {
            actions: [
              { type: 'require_approval', approvals_required: 1, user_approvers_ids: [approver.id] },
              { type: 'require_approval', approvals_required: 1, role_approvers: ['maintainer'] }
            ]
          }
        )
        project.add_developer(approver)
        project.add_maintainer(maintainer)
      end

      it_behaves_like 'calls sync_merge_requests' do
        let(:action) { update_rules }
      end

      it 'updates approval rules and scan_result_policy_reads', :aggregate_failures do
        update_rules

        expect(project.approval_rules.first.approvers).to contain_exactly(approver)
        expect(project.approval_rules.last.approvers).to contain_exactly(maintainer)
        expect(project.scan_result_policy_reads.last.role_approvers)
          .to contain_exactly(Gitlab::Access.sym_options_with_owner[:maintainer])
      end
    end
  end

  describe '#sync_policy_diff' do
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

    subject(:sync_policy_diff) { service.sync_policy_diff(policy_diff) }

    context 'when require_approval actions are updated' do
      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: policy_configuration,
          orchestration_policy_idx: security_policy.policy_index,
          rule_idx: approval_policy_rule.rule_index,
          approval_policy_rule_id: approval_policy_rule.id
        )
      end

      let_it_be(:project_approval_rule) do
        create(:approval_project_rule, :scan_finding,
          project: project,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: scan_result_policy_read,
          security_orchestration_policy_configuration: policy_configuration
        )
      end

      let_it_be(:maintainer) { create(:user) }
      let_it_be(:approver) { create(:user) }

      let_it_be(:new_actions) do
        [
          { type: 'require_approval', user_approvers_ids: [approver.id], approvals_required: 1 },
          { type: 'require_approval', role_approvers: ['maintainer'], approvals_required: 1 }
        ]
      end

      let_it_be(:policy_diff) do
        Security::SecurityOrchestrationPolicies::PolicyDiff::Diff.new.tap do |diff|
          diff.add_policy_field(:actions,
            [
              { type: 'require_approval', user_approvers_ids: [approver.id], approvals_required: 1 }
            ],
            new_actions)
        end
      end

      before_all do
        project.add_maintainer(maintainer)
        project.add_developer(approver)

        security_policy.update!(content: { actions: new_actions })
      end

      it_behaves_like 'calls sync_merge_requests' do
        let(:action) { sync_policy_diff }
      end

      it 'deletes and recreates approval rules and scan_result_policy_reads', :aggregate_failures do
        expect { sync_policy_diff }
          .to change { ApprovalProjectRule.count }.by(1)
          .and change { Security::ScanResultPolicyRead.count }.by(1)

        expect(project.approval_rules.map(&:approval_policy_action_idx)).to contain_exactly(0, 1)
        expect(project.scan_result_policy_reads.map(&:action_idx)).to contain_exactly(0, 1)
      end
    end
  end

  describe '#protected_branch_ids' do
    let(:security_policy) { create(:security_policy) }
    let(:service) { described_class.new(project: project, security_policy: security_policy) }
    let(:policy_branches_service) { instance_double(Security::SecurityOrchestrationPolicies::PolicyBranchesService) }

    let(:approval_policy_rule) do
      build(:approval_policy_rule, content: {
        branches: %w[main release],
        branch_type: 'protected'
      })
    end

    before do
      allow(Security::SecurityOrchestrationPolicies::PolicyBranchesService)
        .to receive(:new)
        .with(project: project)
        .and_return(policy_branches_service)
    end

    subject(:protected_branch_ids) do
      service.protected_branch_ids(approval_policy_rule)
    end

    context 'when there are matching protected branches' do
      let!(:protected_branch_main) { create(:protected_branch, project: project, name: 'main') }
      let!(:protected_branch_release) { create(:protected_branch, project: project, name: 'release') }
      let!(:protected_branch_dev) { create(:protected_branch, project: project, name: 'development') }

      before do
        allow(policy_branches_service)
          .to receive(:scan_result_branches)
          .and_return(%w[main release])
      end

      it { is_expected.to contain_exactly(protected_branch_main.id, protected_branch_release.id) }
    end

    context 'when there are no matching protected branches' do
      before do
        allow(policy_branches_service)
          .to receive(:scan_result_branches)
          .and_return(['feature'])
      end

      it { is_expected.to be_empty }
    end
  end
end
