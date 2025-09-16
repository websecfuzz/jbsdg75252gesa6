# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Policy, feature_category: :security_policy_management do
  subject(:policy) { create(:security_policy, :require_approval) }

  describe 'associations' do
    it { is_expected.to belong_to(:security_orchestration_policy_configuration) }
    it { is_expected.to have_many(:approval_policy_rules) }
    it { is_expected.to have_many(:security_policy_project_links) }
    it { is_expected.to have_many(:projects).through(:security_policy_project_links) }
    it { is_expected.to have_one(:security_pipeline_execution_policy_config_link) }
    it { is_expected.to have_many(:security_pipeline_execution_project_schedules) }

    it do
      is_expected.to validate_uniqueness_of(:security_orchestration_policy_configuration_id).scoped_to(%i[type
        policy_index])
    end
  end

  describe 'validations' do
    shared_examples 'validates policy content' do
      it { is_expected.to be_valid }

      context 'with invalid content' do
        before do
          policy.content = { foo: "bar" }
        end

        it { is_expected.to be_invalid }
      end
    end

    describe 'content' do
      context 'when policy_type is approval_policy' do
        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is scan_execution_policy' do
        subject(:policy) { create(:security_policy, :scan_execution_policy) }

        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is pipeline_execution_policy' do
        subject(:policy) { create(:security_policy, :pipeline_execution_policy) }

        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is pipeline_execution_schedule_policy' do
        subject(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is vulnerability_management_policy' do
        subject(:policy) { create(:security_policy, :vulnerability_management_policy) }

        it_behaves_like 'validates policy content'
      end
    end

    describe 'scope' do
      it { is_expected.to be_valid }

      context 'with empty scope' do
        before do
          policy.scope = {}
        end

        it { is_expected.to be_valid }
      end

      context 'with invalid scope' do
        before do
          policy.scope = { compliance_frameworks: "bar" }
        end

        it { is_expected.to be_invalid }
      end
    end

    describe 'description' do
      context 'when description is greater than the limit' do
        before do
          policy.description = 'a' * (Gitlab::Database::MAX_TEXT_SIZE_LIMIT + 1)
        end

        it { is_expected.to be_invalid }
      end

      context 'when description is less than the limit' do
        it { is_expected.to be_valid }
      end
    end
  end

  describe '.undeleted' do
    let_it_be(:policy_with_positive_index) { create(:security_policy, policy_index: 1) }
    let_it_be(:policy_with_zero_index) { create(:security_policy, policy_index: 0) }
    let_it_be(:policy_with_negative_index) { create(:security_policy, policy_index: -1) }

    it 'returns policies with policy_index greater than or equal to 0' do
      result = described_class.undeleted

      expect(result).to contain_exactly(policy_with_positive_index, policy_with_zero_index)
      expect(result).not_to include(policy_with_negative_index)
    end
  end

  describe '.order_by_index' do
    let_it_be(:policy1) { create(:security_policy, policy_index: 2) }
    let_it_be(:policy2) { create(:security_policy, policy_index: 1) }
    let_it_be(:policy3) { create(:security_policy, policy_index: 3) }

    it 'orders policies by policy_index in ascending order' do
      ordered_policies = described_class.order_by_index

      expect(ordered_policies).to match_array([policy2, policy1, policy3])
    end
  end

  describe '.for_policy_configuration' do
    let_it_be(:policy_configuration1) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_configuration2) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy1) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration1) }
    let_it_be(:policy2) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration2) }

    it 'returns policies for given policy configuration' do
      expect(described_class.for_policy_configuration(policy_configuration1)).to contain_exactly(policy1)
    end

    it 'returns policies for multiple policy configurations' do
      expect(described_class.for_policy_configuration([policy_configuration1, policy_configuration2]))
        .to contain_exactly(policy1, policy2)
    end
  end

  describe '.for_custom_role' do
    let_it_be(:custom_role_id) { 123 }
    let_it_be(:policy_with_role) do
      create(:security_policy, content: {
        actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: [custom_role_id] }]
      })
    end

    let_it_be(:policy_with_different_role) do
      create(:security_policy, content: {
        actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: [456] }]
      })
    end

    let_it_be(:policy_without_role) do
      create(:security_policy, :require_approval)
    end

    it 'returns policies that include the specified custom role' do
      expect(described_class.for_custom_role(custom_role_id)).to contain_exactly(policy_with_role)
    end

    it 'does not return policies without the specified custom role' do
      expect(described_class.for_custom_role(custom_role_id))
        .not_to include(policy_with_different_role, policy_without_role)
    end
  end

  describe '#link_project!' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy) { create(:security_policy) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }

    it 'creates a new link if one does not exist' do
      expect { policy.link_project!(project) }.to change { Security::PolicyProjectLink.count }.by(1)
        .and change { Security::ApprovalPolicyRuleProjectLink.count }.by(1)
    end

    it 'does not create a duplicate link' do
      policy.link_project!(project)

      expect { policy.link_project!(project) }.to not_change { Security::PolicyProjectLink.count }
        .and not_change { Security::ApprovalPolicyRuleProjectLink.count }
    end

    context 'when policy is a pipeline execution schedule policy' do
      let_it_be(:policy) do
        create(
          :security_policy,
          :pipeline_execution_schedule_policy,
          content: {
            content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
            schedules: [
              { type: "daily", start_time: "00:00", time_window: { value: 4000, distribution: 'random' } }
            ]
          }
        )
      end

      it 'creates a new schedule with the right attributes' do
        # Newly introduced columns will be written by https://gitlab.com/gitlab-org/gitlab/-/merge_requests/180714
        pending "schedule creation not currently in place"

        expect { policy.link_project!(project) }.to change { Security::PolicyProjectLink.count }.by(1)
        .and change { Security::PipelineExecutionProjectSchedule.count }.by(1)

        schedule = policy.security_pipeline_execution_project_schedules.first

        expect(schedule.project).to eq(project)
        expect(schedule.security_policy).to eq(policy)
      end
    end
  end

  describe '#unlink_project!' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy) { create(:security_policy) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }

    context 'when link already exists' do
      before do
        create(:security_policy_project_link, project: project, security_policy: policy)
        create(:approval_policy_rule_project_link, approval_policy_rule: approval_policy_rule, project: project)
      end

      it 'removes the link between the policy and the project' do
        expect { policy.unlink_project!(project) }
          .to change { Security::PolicyProjectLink.count }.by(-1)
          .and change { Security::ApprovalPolicyRuleProjectLink.count }.by(-1)
      end
    end

    it 'does nothing if no link exists' do
      expect { policy.unlink_project!(project) }
        .to not_change { Security::PolicyProjectLink.count }
        .and not_change { Security::ApprovalPolicyRuleProjectLink.count }
    end

    context 'when policy is a pipeline execution schedule policy' do
      let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      before do
        create(:security_policy_project_link, project: project, security_policy: policy)
        create(:security_pipeline_execution_project_schedule, project: project, security_policy: policy)
      end

      it 'removes the schedule' do
        expect { policy.unlink_project!(project) }.to change { Security::PolicyProjectLink.count }.by(-1)
        .and change { Security::PipelineExecutionProjectSchedule.count }.by(-1)
      end
    end
  end

  describe '#update_project_approval_policy_rule_links' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy) { create(:security_policy) }

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }
    let_it_be(:deleted_approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }

    let(:created_rules) { [approval_policy_rule] }
    let(:deleted_rules) { [deleted_approval_policy_rule] }

    before do
      create(:approval_policy_rule_project_link, approval_policy_rule: deleted_approval_policy_rule, project: project)
    end

    it 'updates links for created and deleted rules' do
      policy.update_project_approval_policy_rule_links(project, created_rules, deleted_rules)

      expect(
        Security::ApprovalPolicyRuleProjectLink.for_project(project).map(&:approval_policy_rule)
      ).to contain_exactly(approval_policy_rule)
    end
  end

  describe '.upsert_policy' do
    shared_examples 'upserts policy' do |policy_type, assoc_name|
      let(:policy_configuration) { create(:security_orchestration_policy_configuration) }
      let(:policies) { policy_configuration.security_policies.where(type: policy_type) }
      let(:policy_index) { 0 }
      let(:upserted_rules) do
        assoc_name ? upserted_policy.association(assoc_name.to_s).load_target : []
      end

      subject(:upsert!) do
        described_class.upsert_policy(policy_type, policies, policy_hash, policy_index, policy_configuration)
      end

      context 'when the policy does not exist' do
        let(:upserted_policy) { policy_configuration.security_policies.last }

        it 'creates a new policy' do
          expect { upsert! }.to change { policies.count }.by(1)
          expect(upserted_policy.name).to eq(policy_hash[:name])
          expect(upserted_rules.count).to be(assoc_name ? 1 : 0)
        end
      end

      context 'with existing policy' do
        let!(:existing_policy) do
          create(:security_policy,
            policy_type,
            security_orchestration_policy_configuration: policy_configuration,
            policy_index: policy_index)
        end

        let(:upserted_policy) { existing_policy.reload }

        it 'updates the policy' do
          expect { upsert! }.not_to change { policies.count }
          expect(upserted_policy).to eq(existing_policy)
          expect(upserted_policy.name).to eq(policy_hash[:name])
          expect(upserted_rules.count).to be(assoc_name ? 1 : 0)
        end

        context 'when existing policy has metadata persisted' do
          let!(:existing_policy) do
            create(:security_policy,
              policy_type,
              security_orchestration_policy_configuration: policy_configuration,
              policy_index: policy_index,
              metadata: { enforced_scans: ['sast'] })
          end

          it 'does not overwrite the metadata' do
            expect { upsert! }.not_to change { existing_policy.reload.metadata }.from('enforced_scans' => ['sast'])
          end
        end
      end
    end

    context "with approval policies" do
      include_examples 'upserts policy', :approval_policy, :approval_policy_rules do
        let(:policy_hash) { build(:approval_policy, name: "foobar") }
      end
    end

    context "with scan execution policies" do
      include_examples 'upserts policy', :scan_execution_policy, :scan_execution_policy_rules do
        let(:policy_hash) { build(:scan_execution_policy, name: "foobar") }
      end
    end

    context "with pipeline execution policies" do
      include_examples 'upserts policy', :pipeline_execution_policy, nil do
        let_it_be(:config_project, reload: true) { create(:project, :empty_repo) }
        let(:policy_hash) do
          build(:pipeline_execution_policy,
            name: "foobar",
            content: { include: [{ project: config_project.full_path, file: 'compliance-pipeline.yml' }] })
        end

        it 'creates a new link to the config project' do
          expect { upsert! }.to change { Security::PipelineExecutionPolicyConfigLink.count }.by(1)
          expect(Security::PipelineExecutionPolicyConfigLink.last.project).to eq config_project
        end
      end
    end

    context "with vulnerability management policies" do
      include_examples 'upserts policy', :vulnerability_management_policy, :vulnerability_management_policy_rules do
        let(:policy_hash) { build(:vulnerability_management_policy, name: "foobar") }
      end
    end
  end

  describe '.delete_by_ids' do
    let_it_be(:policies) { create_list(:security_policy, 3) }

    subject(:delete!) { described_class.delete_by_ids(policies.first(2).pluck(:id)) }

    it 'deletes by ID' do
      expect { delete! }.to change { described_class.all }.to(contain_exactly(policies.last))
    end
  end

  describe '#to_policy_hash' do
    subject(:policy_hash) { policy.to_policy_hash }

    context 'when policy is an approval policy' do
      let_it_be(:policy) { create(:security_policy, :require_approval, :with_policy_scope) }

      let_it_be(:rule_content) do
        {
          type: 'scan_finding',
          branches: [],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }
      end

      before do
        create(:approval_policy_rule, :scan_finding, security_policy: policy, content: rule_content)
      end

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: policy.scope.deep_symbolize_keys,
          metadata: {},
          actions: [{ approvals_required: 1, type: "require_approval", user_approvers: ["owner"] }],
          rules: [rule_content]
        )
      end
    end

    context 'when policy is a scan execution policy' do
      let_it_be(:policy) { create(:security_policy, :scan_execution_policy) }

      before do
        create(:scan_execution_policy_rule, :pipeline, security_policy: policy)
      end

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: {},
          metadata: {},
          actions: [{ scan: 'secret_detection' }],
          skip_ci: { allowed: true },
          rules: [{ type: 'pipeline', branches: [] }]
        )
      end
    end

    context 'when policy is a pipeline execution policy' do
      let_it_be(:policy) { create(:security_policy, :pipeline_execution_policy) }

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: {},
          metadata: {},
          pipeline_config_strategy: 'inject_ci',
          skip_ci: { allowed: false },
          variables_override: { allowed: false },
          content: { include: [{ file: "compliance-pipeline.yml", project: "compliance-project" }] }
        )
      end
    end

    context 'when policy is a pipeline execution schedule policy' do
      let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: {},
          schedules: [{ start_time: "00:00", time_window: { distribution: "random", value: 4000 }, type: "daily" }],
          metadata: {},
          content: { include: [{ file: "compliance-pipeline.yml", project: "compliance-project" }] }
        )
      end
    end
  end

  describe '#rules' do
    let_it_be(:approval_policy) { create(:security_policy, :require_approval) }
    let_it_be(:scan_execution_policy) { create(:security_policy, :scan_execution_policy) }
    let_it_be(:pipeline_execution_policy) { create(:security_policy, :pipeline_execution_policy) }
    let_it_be(:vulnerability_management_policy) { create(:security_policy, :vulnerability_management_policy) }

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: approval_policy) }

    let_it_be(:negative_index_ap_rule) do
      create(:approval_policy_rule, security_policy: approval_policy, rule_index: -1)
    end

    let_it_be(:scan_execution_policy_rule) do
      create(:scan_execution_policy_rule, security_policy: scan_execution_policy)
    end

    let_it_be(:vulnerability_management_policy_rule) do
      create(:vulnerability_management_policy_rule, security_policy: vulnerability_management_policy)
    end

    let_it_be(:negative_index_se_rule) do
      create(:scan_execution_policy_rule, security_policy: scan_execution_policy, rule_index: -1)
    end

    subject(:rules) { policy.rules }

    context 'when policy is an approval policy' do
      let(:policy) { approval_policy }

      it { is_expected.to contain_exactly(approval_policy_rule) }
    end

    context 'when policy is a scan execution policy' do
      let(:policy) { scan_execution_policy }

      it { is_expected.to contain_exactly(scan_execution_policy_rule) }
    end

    context 'when policy is a pipeline execution policy' do
      let(:policy) { pipeline_execution_policy }

      it { is_expected.to be_empty }
    end

    context 'when policy is a vulnerability management policy' do
      let(:policy) { vulnerability_management_policy }

      it { is_expected.to contain_exactly(vulnerability_management_policy_rule) }
    end
  end

  describe '#max_rule_index' do
    let_it_be(:policy) { create(:security_policy) }
    let_it_be(:rule1) { create(:approval_policy_rule, security_policy: policy, rule_index: 0) }
    let_it_be(:rule2) { create(:approval_policy_rule, security_policy: policy, rule_index: -2) }
    let_it_be(:rule3) { create(:approval_policy_rule, security_policy: policy, rule_index: 1) }

    it 'returns the maximum absolute rule index' do
      expect(policy.max_rule_index).to eq(2)
    end

    context 'when all_rules is nil' do
      before do
        allow(policy).to receive(:all_rules).and_return(nil)
      end

      it 'returns zero' do
        expect(policy.max_rule_index).to eq(0)
      end
    end
  end

  describe '#next_rule_index' do
    let_it_be(:policy) { create(:security_policy) }

    context 'when there are no rules' do
      it 'returns 0' do
        expect(policy.next_rule_index).to eq(0)
      end
    end

    context 'when there are existing rules' do
      let_it_be(:rule1) { create(:approval_policy_rule, security_policy: policy, rule_index: 0) }
      let_it_be(:rule2) { create(:approval_policy_rule, security_policy: policy, rule_index: 1) }
      let_it_be(:deleted_rule) { create(:approval_policy_rule, security_policy: policy, rule_index: -1) }

      it 'returns the next available index' do
        expect(policy.next_rule_index).to eq(2)
      end
    end
  end

  describe '#scope_applicable?' do
    let_it_be(:project) { create(:project) }
    let(:policy) { build(:security_policy) }

    let(:policy_scope_checker) { instance_double(Security::SecurityOrchestrationPolicies::PolicyScopeChecker) }

    before do
      allow(Security::SecurityOrchestrationPolicies::PolicyScopeChecker).to receive(:new)
        .with(project: project).and_return(policy_scope_checker)
    end

    subject(:scope_applicable) { policy.scope_applicable?(project) }

    context 'when the policy is applicable to the project' do
      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).with(policy).and_return(true)
      end

      it { is_expected.to be true }
    end

    context 'when the policy is not applicable to the project' do
      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).with(policy).and_return(false)
      end

      it { is_expected.to be false }
    end
  end

  describe '#scope_has_framework?' do
    let(:framework) { create(:compliance_framework) }
    let(:policy_scope) { {} }
    let(:security_policy) { create(:security_policy, scope: policy_scope) }

    subject(:scope_has_framework?) { security_policy.scope_has_framework?(framework.id) }

    context 'when scope is empty' do
      it { is_expected.to be_falsey }
    end

    context 'when scope contains framework_id' do
      let(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }

      it { is_expected.to be_truthy }
    end

    context 'when scope has a non existing framework_id' do
      let(:policy_scope) { { compliance_frameworks: [{ id: non_existing_record_id }] } }

      it { is_expected.to be_falsey }
    end
  end

  describe '#delete_approval_policy_rules' do
    let_it_be(:policy) { create(:security_policy, :require_approval) }
    let_it_be(:other_policy) { create(:security_policy, :require_approval) }
    let_it_be(:other_policy_rule) { create(:approval_policy_rule, security_policy: other_policy) }

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }
    let_it_be(:approval_project_rule) do
      create(:approval_project_rule,
        security_orchestration_policy_configuration: policy.security_orchestration_policy_configuration,
        approval_policy_rule_id: approval_policy_rule.id
      )
    end

    let_it_be(:approval_merge_request_rule) do
      create(:approval_merge_request_rule,
        security_orchestration_policy_configuration: policy.security_orchestration_policy_configuration,
        approval_policy_rule_id: approval_policy_rule.id
      )
    end

    let_it_be(:violation) { create(:scan_result_policy_violation, approval_policy_rule: approval_policy_rule) }
    let_it_be(:license_policy) { create(:software_license_policy, approval_policy_rule: approval_policy_rule) }

    it 'deletes all associations and approval_policy_rule' do
      expect { policy.delete_approval_policy_rules }.to change { ApprovalProjectRule.count }.by(-1)
        .and change { ApprovalMergeRequestRule.count }.by(-1)
        .and change { Security::ScanResultPolicyViolation.count }.by(-1)
        .and change { SoftwareLicensePolicy.count }.by(-1)
        .and change { Security::ApprovalPolicyRule.count }.by(-1)
    end

    it 'does not delete approval_policy_rules from other policies' do
      expect { policy.delete_approval_policy_rules }.not_to change { other_policy_rule.reload }
    end

    context 'with merged mr rules' do
      let_it_be(:merged_rule) do
        create(:approval_merge_request_rule,
          security_orchestration_policy_configuration: policy.security_orchestration_policy_configuration,
          approval_policy_rule_id: approval_policy_rule.id
        )
      end

      before do
        merged_rule.merge_request.update!(state_id: MergeRequest.available_states[:merged])
      end

      it 'only deletes unmerged ApprovalMergeRequestRules' do
        expect { policy.delete_approval_policy_rules }.to change { ApprovalMergeRequestRule.count }.by(-1)
        expect(ApprovalMergeRequestRule.exists?(merged_rule.id)).to be_truthy
      end
    end
  end

  describe '#delete_scan_execution_policy_rules' do
    let_it_be(:policy) { create(:security_policy, :scan_execution_policy) }
    let_it_be(:other_policy) { create(:security_policy, :scan_execution_policy) }
    let_it_be(:other_policy_rule) { create(:scan_execution_policy_rule, security_policy: other_policy) }

    before do
      create_list(:scan_execution_policy_rule, 3, security_policy: policy)
    end

    it 'deletes all associated ScanExecutionPolicyRule' do
      expect { policy.delete_scan_execution_policy_rules }.to change { Security::ScanExecutionPolicyRule.count }.by(-3)
    end

    it 'does not delete ScanExecutionPolicyRule from other policies' do
      expect { policy.delete_scan_execution_policy_rules }.not_to change { other_policy_rule.reload }
    end
  end

  describe '#delete_security_pipeline_execution_project_schedules' do
    let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
    let_it_be(:other_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
    let_it_be(:other_schedule) { create(:security_pipeline_execution_project_schedule, security_policy: other_policy) }

    before do
      create_list(:security_pipeline_execution_project_schedule, 3, security_policy: policy)
    end

    it 'deletes all associated PipelineExecutionProjectSchedule' do
      expect { policy.delete_security_pipeline_execution_project_schedules }.to change {
        Security::PipelineExecutionProjectSchedule.count
      }.by(-3)
    end

    it 'does not delete PipelineExecutionProjectSchedule from other policies' do
      expect { policy.delete_security_pipeline_execution_project_schedules }.not_to change { other_schedule.reload }
    end
  end

  describe '#delete_approval_policy_rules_for_project' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy) do
      create(:security_policy, :approval_policy, security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }
    let_it_be(:other_approval_policy_rule) { create(:approval_policy_rule) }

    let_it_be(:rules) { policy.approval_policy_rules }

    let_it_be(:approval_project_rule) do
      create(:approval_project_rule,
        project: project,
        security_orchestration_policy_configuration: policy_configuration,
        approval_policy_rule: approval_policy_rule
      )
    end

    let_it_be(:merge_request_rule) do
      create(:approval_merge_request_rule,
        approval_project_rule: approval_project_rule,
        merge_request: merge_request,
        security_orchestration_policy_configuration: policy_configuration,
        approval_policy_rule: approval_policy_rule
      )
    end

    let_it_be(:violation) do
      create(:scan_result_policy_violation,
        project: project,
        approval_policy_rule: approval_policy_rule)
    end

    let_it_be(:license_policy) do
      create(:software_license_policy,
        project: project,
        approval_policy_rule: approval_policy_rule
      )
    end

    let_it_be(:other_approval_project_rule) do
      create(:approval_project_rule,
        project: project,
        security_orchestration_policy_configuration: policy_configuration,
        approval_policy_rule: other_approval_policy_rule
      )
    end

    let_it_be(:other_merge_request_rule) do
      create(:approval_merge_request_rule,
        approval_project_rule: approval_project_rule,
        merge_request: merge_request,
        security_orchestration_policy_configuration: policy_configuration,
        approval_policy_rule: other_approval_policy_rule
      )
    end

    let_it_be(:other_violation) do
      create(:scan_result_policy_violation,
        project: project,
        approval_policy_rule: other_approval_policy_rule)
    end

    let_it_be(:other_license_policy) do
      create(:software_license_policy,
        project: project,
        approval_policy_rule: other_approval_policy_rule
      )
    end

    it 'removes all associated records' do
      expect do
        policy.delete_approval_policy_rules_for_project(project, rules)
      end.to change { ApprovalProjectRule.count }.by(-1)
        .and change { ApprovalMergeRequestRule.count }.by(-1)
        .and change { SoftwareLicensePolicy.count }.by(-1)
        .and change { Security::ScanResultPolicyViolation.count }.by(-1)
    end

    it 'does not delete records from other approval policy rules' do
      policy.delete_approval_policy_rules_for_project(project, rules)

      expect(project.approval_rules).to include(other_approval_project_rule)
      expect(project.approval_merge_request_rules).to include(other_merge_request_rule)
      expect(project.software_license_policies).to include(other_license_policy)
      expect(project.scan_result_policy_violations).to include(other_violation)
    end
  end

  describe '#delete_scan_result_policy_reads_for_project' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:policy) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration) }
    let_it_be(:approval_policy_rules) { create_list(:approval_policy_rule, 3, security_policy: policy) }

    let_it_be(:other_policy) { create(:security_policy, :approval_policy) }
    let_it_be(:other_policy_rules) { create_list(:approval_policy_rule, 3, security_policy: other_policy) }

    let_it_be(:rules) { approval_policy_rules.first(2) }

    before do
      approval_policy_rules.each do |rule|
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: policy_configuration,
          approval_policy_rule: rule)
      end
      other_policy_rules.each do |rule|
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: other_policy.security_orchestration_policy_configuration,
          approval_policy_rule: rule)
      end
    end

    subject(:delete_scan_result_policy_reads_for_project) do
      policy.delete_scan_result_policy_reads_for_project(project, rules)
    end

    it 'deletes only the scan result policy reads for the given rules' do
      expect do
        delete_scan_result_policy_reads_for_project
      end.to change { project.scan_result_policy_reads.count }.by(-2)

      expect(project.scan_result_policy_reads.where(approval_policy_rule: approval_policy_rules).count).to eq(1)
      expect(project.scan_result_policy_reads.where(approval_policy_rule: other_policy_rules).count).to eq(3)
    end
  end

  describe '#edit_path' do
    subject(:edit_path) { policy.edit_path }

    let_it_be(:project_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:namespace_configuration) { create(:security_orchestration_policy_configuration, :namespace) }

    context 'when name is nil' do
      let(:policy) { build(:security_policy, name: nil) }

      it { is_expected.to be_nil }
    end

    shared_examples_for 'a valid url for policy type' do |type|
      context 'when it belongs to project configuration' do
        let(:configuration) { project_configuration }

        it 'returns a valid url' do
          expect(edit_path).to eq(
            Gitlab::Routing.url_helpers.edit_project_security_policy_url(
              project_configuration.project, id: CGI.escape('Policy'), type: type
            )
          )
        end
      end

      context 'when it belongs to namespace configuration' do
        let(:configuration) { namespace_configuration }

        it 'returns a valid url' do
          expect(edit_path).to eq(
            Gitlab::Routing.url_helpers.edit_group_security_policy_url(
              namespace_configuration.namespace, id: CGI.escape('Policy'), type: type
            )
          )
        end
      end
    end

    context 'when type is approval_policy' do
      let(:policy) do
        build(:security_policy, name: 'Policy', security_orchestration_policy_configuration: configuration)
      end

      it_behaves_like 'a valid url for policy type', 'approval_policy'
    end

    context 'when type is scan_execution_policy' do
      let(:policy) do
        build(:security_policy, :scan_execution_policy, name: 'Policy',
          security_orchestration_policy_configuration: configuration)
      end

      it_behaves_like 'a valid url for policy type', 'scan_execution_policy'
    end

    context 'when type is pipeline_execution_policy' do
      let(:policy) do
        build(:security_policy, :pipeline_execution_policy, name: 'Policy',
          security_orchestration_policy_configuration: configuration)
      end

      it_behaves_like 'a valid url for policy type', 'pipeline_execution_policy'
    end

    context 'when type is vulnerability_management_policy' do
      let(:policy) do
        build(:security_policy, :vulnerability_management_policy, name: 'Policy',
          security_orchestration_policy_configuration: configuration)
      end

      it_behaves_like 'a valid url for policy type', 'vulnerability_management_policy'
    end
  end

  describe '#update_pipeline_execution_policy_config_link!' do
    subject(:update_links) { policy.update_pipeline_execution_policy_config_link! }

    let_it_be(:config_project, reload: true) { create(:project, :empty_repo) }
    let(:policy) do
      create(:security_policy, :pipeline_execution_policy, content: {
        content: { include: [{ project: config_project.full_path, file: 'compliance-pipeline.yml' }] },
        pipeline_config_strategy: 'inject_ci'
      })
    end

    it 'creates a new link if one does not exist' do
      expect { update_links }.to change { Security::PipelineExecutionPolicyConfigLink.count }.by(1)
      expect(policy.reload.security_pipeline_execution_policy_config_link.project).to eq config_project
    end

    it 'does not create a duplicate link' do
      update_links

      expect { policy.update_pipeline_execution_policy_config_link! }
        .not_to change { Security::PipelineExecutionPolicyConfigLink.count }.from(1)
    end

    context 'when policy was previously linked to another project' do
      let_it_be(:other_config_project) { create(:project, :empty_repo) }

      before do
        create(:security_pipeline_execution_policy_config_link, security_policy: policy, project: other_config_project)
      end

      it 'replaces the link' do
        update_links

        expect(policy.reload.security_pipeline_execution_policy_config_link.project).to eq config_project
      end
    end

    context 'when the linked config project does not exist' do
      before do
        config_project.destroy!
      end

      it 'does not create any link' do
        expect { update_links }.not_to change { Security::PipelineExecutionPolicyConfigLink.count }
      end
    end

    %i[approval_policy scan_execution_policy vulnerability_management_policy].each do |type|
      context "when policy is #{type}" do
        let(:policy) { create(:security_policy, type) }

        it { expect  { update_links }.not_to change { Security::PipelineExecutionPolicyConfigLink.count } }
      end
    end
  end

  describe '#pipeline_execution_ci_config' do
    subject(:ci_config) { policy.pipeline_execution_ci_config }

    let(:policy) { build(:security_policy, :pipeline_execution_policy) }

    it 'returns CI config path' do
      expect(ci_config).to eq({ "project" => 'compliance-project', "file" => "compliance-pipeline.yml" })
    end

    context 'when policy does not include a CI config' do
      %i[approval_policy scan_execution_policy vulnerability_management_policy].each do |type|
        context "when policy is #{type}" do
          let(:policy) { build(:security_policy, type) }

          it { is_expected.to be_nil }
        end
      end
    end
  end

  describe '#warn_mode?' do
    subject(:warn_mode) { policy.warn_mode? }

    context 'when content is nil' do
      let(:policy) { build(:security_policy, content: nil) }

      it { is_expected.to be false }
    end

    context 'when actions are not present' do
      let(:policy) { build(:security_policy, content: {}) }

      it { is_expected.to be false }
    end

    context 'when actions are present' do
      context 'with no require_approval actions' do
        let(:policy) { build(:security_policy, content: { actions: [{ type: 'other_action' }] }) }

        it { is_expected.to be false }
      end

      context 'with require_approval actions' do
        context 'when all require_approval actions have approvals_required set to 0' do
          let(:policy) do
            build(:security_policy, content: {
              actions: [
                { type: 'require_approval', approvals_required: 0 },
                { type: 'require_approval', approvals_required: 0 }
              ]
            })
          end

          it { is_expected.to be true }
        end

        context 'when at least one require_approval action has approvals_required greater than 0' do
          let(:policy) do
            build(:security_policy, content: {
              actions: [
                { type: 'require_approval', approvals_required: 0 },
                { type: 'require_approval', approvals_required: 1 }
              ]
            })
          end

          it { is_expected.to be false }
        end

        context 'when mixed with other action types' do
          context 'when all require_approval actions have approvals_required set to 0' do
            let(:policy) do
              build(:security_policy, content: {
                actions: [
                  { type: 'require_approval', approvals_required: 0 },
                  { type: 'other_action' },
                  { type: 'require_approval', approvals_required: 0 }
                ]
              })
            end

            it { is_expected.to be true }
          end

          context 'when at least one require_approval action has approvals_required greater than 0' do
            let(:policy) do
              build(:security_policy, content: {
                actions: [
                  { type: 'require_approval', approvals_required: 0 },
                  { type: 'other_action' },
                  { type: 'require_approval', approvals_required: 1 }
                ]
              })
            end

            it { is_expected.to be false }
          end
        end

        context 'when only other action types are present' do
          let(:policy) do
            build(:security_policy, content: {
              actions: [
                { type: 'other_action' },
                { type: 'another_action' }
              ]
            })
          end

          it { is_expected.to be false }
        end
      end
    end
  end

  describe '#enforced_scans' do
    subject(:enforced_scans) { policy.enforced_scans }

    let(:policy) { build(:security_policy, :pipeline_execution_policy, metadata: metadata) }
    let(:metadata) { { enforced_scans: %w[secret_detection] } }

    it { is_expected.to eq %w[secret_detection] }

    context 'when metadata is empty' do
      let(:metadata) { {} }

      it { is_expected.to eq [] }
    end

    context 'when metadata does not contain enforced_scans' do
      let(:metadata) { { other: 'property' } }

      it { is_expected.to eq [] }
    end
  end

  describe '#enforced_scans=' do
    let(:policy) { build(:security_policy, :pipeline_execution_policy, metadata: metadata) }
    let(:metadata) { {} }

    it 'updates metadata' do
      policy.enforced_scans = %w[secret_detection]

      expect(policy.metadata).to eq('enforced_scans' => %w[secret_detection])
    end

    context 'when metadata contains other properties' do
      let(:metadata) { { other: 'property' } }

      it 'updates extends metadata and keeps the other property' do
        policy.enforced_scans = %w[secret_detection]

        expect(policy.metadata).to eq('enforced_scans' => %w[secret_detection], 'other' => 'property')
      end
    end
  end

  describe '#framework_ids_from_scope' do
    let_it_be(:policy) { build(:security_policy) }

    subject(:framework_ids) { policy.framework_ids_from_scope }

    context 'when scope is empty' do
      let_it_be(:policy) { build(:security_policy, scope: {}) }

      it { is_expected.to be_empty }
    end

    context 'when scope has compliance frameworks' do
      let_it_be(:policy) do
        build(:security_policy, scope: {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ]
        })
      end

      it 'returns framework_ids' do
        expect(framework_ids).to contain_exactly(1, 2)
      end
    end

    context 'when scope has duplicatecompliance frameworks' do
      let_it_be(:policy) do
        build(:security_policy, scope: {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 },
            { id: 1 }
          ]
        })
      end

      it 'returns unique framework_ids' do
        expect(framework_ids).to contain_exactly(1, 2)
      end
    end

    context 'when scope has no compliance frameworks' do
      let_it_be(:policy) do
        build(:security_policy, scope: {
          projects: { including: [{ id: 1 }] }
        })
      end

      it { is_expected.to be_empty }
    end
  end

  describe '#upsert_rule' do
    let_it_be(:policy) { create(:security_policy, :approval_policy) }
    let_it_be(:policy_configuration) { policy.security_orchestration_policy_configuration }

    let_it_be(:rule_index) { 0 }
    let_it_be(:rule_hash) do
      {
        type: 'scan_finding',
        branches: [],
        scanners: %w[container_scanning],
        vulnerabilities_allowed: 0,
        severity_levels: %w[critical],
        vulnerability_states: %w[detected]
      }
    end

    subject(:upsert!) { policy.upsert_rule(rule_index, rule_hash) }

    context 'when rule does not exist' do
      before do
        Security::ApprovalPolicyRule.delete_all
      end

      it 'creates a new rule' do
        expect { upsert! }.to change { Security::ApprovalPolicyRule.count }.by(1)
        expect(upsert!).to have_attributes(security_policy_id: policy.id, rule_index: rule_index, type: 'scan_finding')
      end
    end

    context 'when rule exists' do
      it 'updates the existing rule' do
        expect { upsert! }.not_to change { Security::ApprovalPolicyRule.count }
        expect(upsert!).to have_attributes(security_policy_id: policy.id, rule_index: rule_index)
      end
    end
  end

  describe '.next_deletion_index' do
    let_it_be(:policy_with_positive_index) { create(:security_policy, policy_index: 1) }
    let_it_be(:policy_with_zero_index) { create(:security_policy, policy_index: 0) }
    let_it_be(:policy_with_negative_index) { create(:security_policy, policy_index: -1) }

    it 'returns the next available deletion index' do
      expect(described_class.next_deletion_index).to eq(2)
    end

    context 'when there are no policies' do
      before do
        described_class.delete_all
      end

      it 'returns 1' do
        expect(described_class.next_deletion_index).to eq(1)
      end
    end

    context 'when there are only negative indices' do
      let_it_be(:policy_with_negative_index2) { create(:security_policy, policy_index: -2) }
      let_it_be(:policy_with_negative_index3) { create(:security_policy, policy_index: -3) }

      it 'returns the next available positive index' do
        expect(described_class.next_deletion_index).to eq(4)
      end
    end

    context 'when there are only positive indices' do
      let_it_be(:policy_with_positive_index2) { create(:security_policy, policy_index: 2) }
      let_it_be(:policy_with_positive_index3) { create(:security_policy, policy_index: 3) }

      it 'returns the next available index' do
        expect(described_class.next_deletion_index).to eq(4)
      end
    end
  end

  describe '#policy_content' do
    let_it_be(:policy) { create(:security_policy, :require_approval) }

    it 'returns content with symbol keys' do
      expect(policy.policy_content).to eq({
        actions: [{ type: 'require_approval', approvals_required: 1, user_approvers: %w[owner] }]
      })
    end
  end

  describe '.with_bypass_settings' do
    let_it_be(:policy_with_bypass) do
      create(:security_policy, bypass_access_token_ids: [1])
    end

    let_it_be(:policy_without_bypass) do
      create(:security_policy, :require_approval)
    end

    let_it_be(:policy_with_empty_bypass) { create(:security_policy, content: { bypass_settings: {} }) }

    it 'returns only policies with non-empty bypass_settings' do
      result = described_class.with_bypass_settings
      expect(result).to contain_exactly(policy_with_bypass)
    end
  end

  describe '#bypass_settings' do
    let(:access_token_id) { 42 }
    let(:service_account_id) { 99 }

    context 'when bypass_settings is nil' do
      let(:policy) { build(:security_policy, content: {}) }

      it 'returns a BypassSettings object with nil ids' do
        expect(policy.bypass_settings.access_token_ids).to be_nil
        expect(policy.bypass_settings.service_account_ids).to be_nil
      end
    end

    context 'when bypass_settings is empty' do
      let(:policy) { build(:security_policy, content: { bypass_settings: {} }) }

      it 'returns a BypassSettings object with nil ids' do
        expect(policy.bypass_settings.access_token_ids).to be_nil
        expect(policy.bypass_settings.service_account_ids).to be_nil
      end
    end

    context 'when bypass_settings has access_tokens and service_accounts' do
      let(:policy) do
        build(:security_policy,
          bypass_access_token_ids: [access_token_id],
          bypass_service_account_ids: [service_account_id]
        )
      end

      it 'returns the correct ids' do
        expect(policy.bypass_settings.access_token_ids).to contain_exactly(access_token_id)
        expect(policy.bypass_settings.service_account_ids).to contain_exactly(service_account_id)
      end
    end
  end
end
