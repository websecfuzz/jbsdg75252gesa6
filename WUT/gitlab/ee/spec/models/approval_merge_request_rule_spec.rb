# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalMergeRequestRule, factory_default: :keep, feature_category: :code_review do
  let_it_be_with_reload(:project) { create_default(:project, :repository) }
  let_it_be_with_reload(:merge_request) { create_default(:merge_request) }

  subject { create(:approval_merge_request_rule, merge_request: merge_request) }

  describe 'associations' do
    subject { build_stubbed(:approval_merge_request_rule) }

    it { is_expected.to have_one(:approval_project_rule_project).through(:approval_project_rule) }
    it { is_expected.to have_one(:approval_project_rule).through(:approval_merge_request_rule_source) }
    it { is_expected.to have_many(:approval_merge_request_rules_users) }

    it do
      is_expected.to have_many(:scan_result_policy_violations)
        .through(:scan_result_policy_read)
        .source(:violations)
    end
  end

  describe 'validations' do
    it 'is valid' do
      expect(build(:approval_merge_request_rule)).to be_valid
    end

    it 'is invalid when the name is missing' do
      expect(build(:approval_merge_request_rule, name: nil)).not_to be_valid
    end

    context 'when the merge request is merged' do
      let(:merge_request) { create(:merge_request, :merged) }
      let(:rule) { build(:approval_merge_request_rule, merge_request: merge_request) }

      context 'when finalizing_rules is true' do
        before do
          merge_request.finalizing_rules = true
        end

        it 'is valid' do
          expect(rule).to be_valid
        end
      end

      context 'when finalizing_rules is not set' do
        it 'is not valid' do
          expect(rule).not_to be_valid
          expect(rule.errors[:merge_request]).to include(/must not be merged/)
        end
      end
    end

    context 'for report type different than scan_finding' do
      it 'is invalid when name not unique within rule type,  merge request and applicable_post_merge' do
        is_expected.to validate_uniqueness_of(:name).scoped_to([:merge_request_id, :rule_type, :section, :applicable_post_merge])
      end
    end

    context 'for scan_finding report type' do
      subject { create(:approval_merge_request_rule, :scan_finding, merge_request: merge_request) }

      it 'is invalid when name not unique within scan result policy, rule type and merge request' do
        is_expected.to validate_uniqueness_of(:name).scoped_to([:merge_request_id, :rule_type, :section, :security_orchestration_policy_configuration_id, :orchestration_policy_idx, :approval_policy_action_idx])
      end
    end

    context 'name uniqueness' do
      context 'when not from scan result policy' do
        it 'validates uniqueness of name scoped to merge_request_id and rule_type' do
          create(:approval_merge_request_rule, merge_request: merge_request, name: 'Test Rule')
          duplicate_rule = build(:approval_merge_request_rule, merge_request: merge_request, name: 'Test Rule')

          expect(duplicate_rule).to be_invalid
          expect(duplicate_rule.errors[:name]).to include('has already been taken')
        end
      end

      context 'when from scan result policy' do
        let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
        let_it_be(:policy_idx) { 1 }
        let_it_be(:action_idx) { 0 }

        it 'validates uniqueness of name scoped to merge_request_id, rule_type, policy_configuration_id, policy_idx, and action_idx' do
          create(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          duplicate_rule = build(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          expect(duplicate_rule).to be_invalid
          expect(duplicate_rule.errors[:name]).to include('has already been taken')
        end

        it 'allows same name with different policy configuration' do
          policy_configuration2 = create(:security_orchestration_policy_configuration, :namespace)
          create(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          rule2 = build(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration2,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          expect(rule2).to be_valid
        end

        it 'allows same name with different policy index' do
          create(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          rule2 = build(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx + 1,
            approval_policy_action_idx: action_idx
          )

          expect(rule2).to be_valid
        end

        it 'allows same name with different action index' do
          create(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          rule2 = build(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx + 1
          )

          expect(rule2).to be_valid
        end
      end
    end

    context 'approval_project_rule is set' do
      let(:approval_project_rule) { build(:approval_project_rule, project: build(:project)) }
      let(:merge_request_rule) { build(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule) }

      context 'when project of approval_project_rule and merge request matches' do
        let(:merge_request) { build(:merge_request, project: approval_project_rule.project) }

        it 'is valid' do
          expect(merge_request_rule).to be_valid
        end
      end

      context 'when the project of approval_project_rule and merge request does not match' do
        it 'is invalid' do
          expect(merge_request_rule).to be_invalid
        end
      end
    end

    context 'code owner rules' do
      it 'is valid' do
        expect(build(:code_owner_rule)).to be_valid
      end

      it 'is invalid when reusing the same name within the same merge request' do
        existing = create(:code_owner_rule, name: '*.rb', merge_request: merge_request, section: 'section')

        new = build(:code_owner_rule, merge_request: existing.merge_request, name: '*.rb', section: 'section')

        expect(new).not_to be_valid
        expect { new.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it 'allows a regular rule with the same name as the codeowner rule' do
        create(:code_owner_rule, name: '*.rb', merge_request: merge_request)

        new = build(:approval_merge_request_rule, name: '*.rb', merge_request: merge_request)

        expect(new).to be_valid
        expect { new.save! }.not_to raise_error
      end
    end

    context 'any_approver rules' do
      let(:rule) do
        build(:approval_merge_request_rule, merge_request: merge_request, rule_type: :any_approver,
          applicable_post_merge: true)
      end

      it 'only allows one rule for every any_approver rule type and applicable_post_merge value' do
        create(:approval_merge_request_rule, merge_request: merge_request, rule_type: :any_approver, applicable_post_merge: false)

        expect(rule).to be_valid
        expect { rule.save!(validate: false) }.not_to raise_error

        dup_rule = build(:approval_merge_request_rule, merge_request: merge_request, rule_type: :any_approver, applicable_post_merge: true)

        expect(dup_rule).not_to be_valid
        expect(dup_rule.errors.messages).to eq(rule_type: ['any-approver for the merge request already exists'])
        expect { dup_rule.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context 'when role_approvers' do
      context 'rule_type is :code_owner' do
        it 'is not valid when not access value' do
          rule = build(:approval_merge_request_rule, rule_type: :code_owner, role_approvers: [1])

          expect(rule).not_to be_valid
          expect(rule.errors.messages).to eq(role_approvers: ["is not included in the list"])
        end

        it 'is valid with an access value' do
          expect(build(:approval_merge_request_rule, rule_type: :code_owner, role_approvers: [Gitlab::Access::DEVELOPER])).to be_valid
        end

        it 'is valid with two access values' do
          expect(build(:approval_merge_request_rule, rule_type: :code_owner, role_approvers: [Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER])).to be_valid
        end
      end

      context 'when rule_type is not :code_owner' do
        it 'is not valid' do
          rule = build(:approval_merge_request_rule, rule_type: :any_approver, role_approvers: [Gitlab::Access::DEVELOPER])

          expect(rule).not_to be_valid
          expect(rule.errors.messages).to eq(role_approvers: ["can only be added to codeowner type rules"])
        end
      end
    end
  end

  describe '.regular_or_any_approver scope' do
    it 'returns regular or any-approver rules' do
      any_approver_rule = create(:any_approver_rule)
      regular_rule = create(:approval_merge_request_rule)
      create(:report_approver_rule)

      expect(described_class.regular_or_any_approver).to(
        contain_exactly(any_approver_rule, regular_rule)
      )
    end
  end

  describe '.not_regular_or_any_approver scope' do
    it 'returns all rules but regular or any-approver' do
      create(:any_approver_rule)
      create(:approval_merge_request_rule)
      licence_rule = create(:report_approver_rule, :license_scanning)
      code_owner_rule = create(:code_owner_rule)
      code_coverage_rule = create(:report_approver_rule, :code_coverage)
      scan_finding_rule = create(:report_approver_rule, :scan_finding)
      any_mr_rule = create(:report_approver_rule, :any_merge_request)

      expect(described_class.not_regular_or_any_approver).to(
        contain_exactly(licence_rule, code_owner_rule, code_coverage_rule, scan_finding_rule, any_mr_rule)
      )
    end
  end

  context 'scopes' do
    let!(:rb_rule) { create(:code_owner_rule, name: '*.rb') }
    let!(:js_rule) { create(:code_owner_rule, name: '*.js') }
    let!(:css_rule) { create(:code_owner_rule, name: '*.css') }
    let!(:approval_rule) { create(:approval_merge_request_rule) }
    let!(:report_approver_rule) { create(:report_approver_rule) }
    let!(:coverage_rule) { create(:report_approver_rule, :code_coverage) }
    let!(:license_rule) { create(:report_approver_rule, :license_scanning) }

    describe '.not_matching_id' do
      it 'returns the correct rules' do
        expect(described_class.not_matching_id([rb_rule.id, js_rule.id]))
          .to contain_exactly(css_rule)
      end
    end

    describe '.matching_pattern' do
      it 'returns the correct rules' do
        expect(described_class.matching_pattern(['*.rb', '*.js']))
          .to contain_exactly(rb_rule, js_rule)
      end
    end

    describe '.code_owners' do
      it 'returns the correct rules' do
        expect(described_class.code_owner)
          .to contain_exactly(rb_rule, js_rule, css_rule)
      end
    end

    describe '.license_compliance' do
      it 'returns the correct rules' do
        expect(described_class.license_compliance)
          .to contain_exactly(license_rule, report_approver_rule)
      end
    end

    describe '.coverage' do
      it 'returns the correct rules' do
        expect(described_class.coverage)
          .to contain_exactly(coverage_rule)
      end
    end
  end

  describe '.applicable_post_merge' do
    it 'returns only the rules applicable_post_merge true or nil' do
      create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: false)
      rule_2 = create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: true)
      rule_3 = create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: nil)

      expect(described_class.applicable_post_merge).to contain_exactly(rule_2, rule_3)
    end
  end

  describe '.find_or_create_code_owner_rule' do
    subject(:rule) { described_class.find_or_create_code_owner_rule(merge_request, entry) }

    let(:entry) { Gitlab::CodeOwners::Entry.new("*.js", "@user") }

    context "when there is an existing rule" do
      context "when the entry does not have the approvals_required field" do
        let!(:existing_code_owner_rule) do
          create(:code_owner_rule, name: '*.rb', merge_request: merge_request)
        end

        let(:entry) { Gitlab::CodeOwners::Entry.new("*.rb", "@user") }

        it 'finds the existing rule' do
          expect(rule).to eq(existing_code_owner_rule)
        end

        context "when the existing rule matches name but not section" do
          let(:entry) { Gitlab::CodeOwners::Entry.new("*.rb", "@user", section: "example_section") }

          it "creates a new rule" do
            expect(rule).not_to eq(existing_code_owner_rule)
          end
        end
      end

      context "when the entry has the approvals_required field" do
        let!(:existing_code_owner_rule) do
          create(:code_owner_rule, name: '*.rb', merge_request: merge_request, approvals_required: 2)
        end

        let(:entry) { Gitlab::CodeOwners::Entry.new("*.rb", "@user", section: "codeowners", optional: false, approvals_required: 2) }

        it 'finds the existing rule' do
          expect(rule).to eq(existing_code_owner_rule)
        end

        context "when the existing rule matches name but not section" do
          let(:entry) { Gitlab::CodeOwners::Entry.new("*.rb", "@user", section: "example_section", optional: false, approvals_required: 2) }

          it "creates a new rule" do
            expect(rule).not_to eq(existing_code_owner_rule)
          end
        end
      end
    end

    it 'creates a new rule if it does not exist' do
      expect { rule }
        .to change { merge_request.approval_rules.matching_pattern('*.js').count }.by(1)
    end

    it 'finds an existing rule using rule_type column' do
      regular_rule_type_rule = create(
        :code_owner_rule,
        name: entry.pattern,
        merge_request: merge_request,
        rule_type: described_class.rule_types[:regular]
      )

      expect(rule).not_to eq(regular_rule_type_rule)
    end

    it 'retries when a record was created between the find and the create' do
      expect(described_class).to receive(:code_owner).and_raise(ActiveRecord::RecordNotUnique)
      allow(described_class).to receive(:code_owner).and_call_original

      expect(rule).not_to be_nil
    end

    context "when section is present" do
      let(:entry) { Gitlab::CodeOwners::Entry.new("*.js", "@user", section: "Test Section") }

      it "creates a new rule and saves section when present" do
        expect(subject.section).to eq(entry.section)
      end
    end
  end

  describe '#project' do
    it 'returns project of MergeRequest' do
      expect(subject.project).to be_present
      expect(subject.project).to eq(merge_request.project)
    end
  end

  describe '#regular' do
    it 'returns true for regular records' do
      subject = create(:approval_merge_request_rule, merge_request: merge_request)

      expect(subject.regular).to eq(true)
      expect(subject.regular?).to eq(true)
    end

    it 'returns false for code owner records' do
      subject = create(:code_owner_rule, merge_request: merge_request)

      expect(subject.regular).to eq(false)
      expect(subject.regular?).to eq(false)
    end

    it 'returns false for any approver records' do
      subject = create(:approval_merge_request_rule, merge_request: merge_request, rule_type: :any_approver)

      expect(subject.regular).to eq(false)
      expect(subject.regular?).to eq(false)
    end
  end

  describe '#code_owner?' do
    let(:code_owner_rule) { build(:code_owner_rule) }

    context "rule_type is :code_owner" do
      it "returns true" do
        expect(code_owner_rule.code_owner?).to be true
      end
    end

    context "rule_type is :regular" do
      before do
        code_owner_rule.rule_type = :regular
      end

      it "returns false" do
        expect(code_owner_rule.code_owner?).to be false
      end
    end
  end

  describe '#approvers' do
    before do
      create(:group) do |group|
        group.add_guest(merge_request.author)
        subject.groups << group
      end
    end

    context 'when project merge_requests_author_approval is true' do
      it 'contains author' do
        merge_request.project.update!(merge_requests_author_approval: true)

        expect(described_class.find(subject.id).approvers).to contain_exactly(merge_request.author)
      end
    end

    context 'when project merge_requests_author_approval is false' do
      before do
        merge_request.project.update!(merge_requests_author_approval: false)
      end

      it 'does not contain author' do
        expect(described_class.find(subject.id).approvers).to be_empty
      end

      context 'when the rules users have already been loaded' do
        before do
          subject.users.to_a
          subject.group_users.to_a
        end

        it 'does not perform any new queries when all users are loaded already' do
          # single query is triggered for license check
          expect { subject.approvers }.not_to exceed_query_limit(1)
        end

        it 'does not contain the author' do
          expect(subject.approvers).to be_empty
        end
      end
    end
  end

  describe '#sync_approved_approvers' do
    let(:member1) { create(:user) }
    let(:member2) { create(:user) }
    let(:member3) { create(:user) }
    let!(:approval1) { create(:approval, merge_request: merge_request, user: member1) }
    let!(:approval2) { create(:approval, merge_request: merge_request, user: member2) }
    let!(:approval3) { create(:approval, merge_request: merge_request, user: member3) }

    let!(:any_approver_rule) { create(:any_approver_rule, merge_request: merge_request) }

    before do
      subject.users = [member1, member2]
    end

    context 'when not merged' do
      it 'does nothing' do
        subject.sync_approved_approvers
        any_approver_rule.sync_approved_approvers

        expect(subject.approved_approvers.reload).to be_empty
        expect(any_approver_rule.approved_approvers).to be_empty
      end
    end

    context 'when merged' do
      let(:merge_request) { create(:merge_request, source_branch: 'test') }

      before do
        merge_request.mark_as_merged!
      end

      context 'when merge request finalizing_rules is true' do
        before do
          subject.merge_request.finalizing_rules = true
        end

        it 'records approved approvers as approved_approvers association' do
          subject.sync_approved_approvers

          expect(subject.reload.approved_approvers).to contain_exactly(member1, member2)
        end

        it 'stores all the approvals for any-approver rule' do
          any_approver_rule.sync_approved_approvers

          expect(any_approver_rule.approved_approvers.reload).to contain_exactly(member1, member2, member3)
        end
      end

      context 'when finalizing_rules is false' do
        before do
          subject.merge_request.finalizing_rules = false
        end

        it 'does nothing' do
          subject.sync_approved_approvers
          any_approver_rule.sync_approved_approvers

          expect(subject.approved_approvers.reload).to be_empty
          expect(any_approver_rule.approved_approvers).to be_empty
        end
      end
    end
  end

  describe 'validations' do
    describe 'approvals_required' do
      subject { build(:approval_merge_request_rule, merge_request: merge_request) }

      it 'is a natural number' do
        subject.assign_attributes(approvals_required: 2)
        expect(subject).to be_valid

        subject.assign_attributes(approvals_required: 0)
        expect(subject).to be_valid

        subject.assign_attributes(approvals_required: -1)
        expect(subject).to be_invalid
      end
    end
  end

  describe '#vulnerability_states_for_branch' do
    let(:vulnerability_states) { [:detected, :new_needs_triage] }
    let(:approval_rule) { create(:approval_merge_request_rule, :scan_finding, vulnerability_states: vulnerability_states, merge_request: merge_request) }

    subject { approval_rule.vulnerability_states_for_branch }

    context 'with target branch equal to project default branch' do
      before do
        allow(merge_request).to receive(:target_branch).and_return("master")
      end

      it 'returns all vulnerability states' do
        expect(subject).to contain_exactly('detected', 'new_needs_triage')
      end
    end

    context 'with target branch different from project default branch' do
      it 'returns only newly detected' do
        expect(subject).to contain_exactly('new_needs_triage')
      end

      context 'when vulnerabilty_states is empty' do
        let(:vulnerability_states) { [] }

        it 'returns only default states' do
          expect(subject).to contain_exactly('new_needs_triage', 'new_dismissed')
        end
      end

      context 'without newly_detected' do
        let(:vulnerability_states) { [:detected, :confirmed] }

        it 'returns empty array' do
          expect(subject).to be_blank
        end
      end
    end
  end

  it_behaves_like '#editable_by_user?' do
    let(:merge_request) { create(:merge_request, :unique_branches, source_project: project, target_project: project) }
    let(:approval_rule) { create(:approval_merge_request_rule, merge_request: merge_request) }
    let(:any_approver_rule) { build(:any_approver_rule, merge_request: merge_request) }
    let(:code_owner_rule) { create(:code_owner_rule, merge_request: merge_request) }
  end

  describe '#hook_attrs' do
    let(:rule) { create(:approval_merge_request_rule, merge_request: merge_request) }

    subject(:hook_attrs) { rule.hook_attrs }

    it 'returns the expected attributes' do
      expect(hook_attrs).to eq({
        id: rule.id,
        approvals_required: rule.approvals_required,
        name: rule.name,
        rule_type: rule.rule_type,
        report_type: rule.report_type,
        merge_request_id: rule.merge_request_id,
        section: rule.section,
        modified_from_project_rule: rule.modified_from_project_rule,
        orchestration_policy_idx: rule.orchestration_policy_idx,
        vulnerabilities_allowed: rule.vulnerabilities_allowed,
        scanners: rule.scanners,
        severity_levels: rule.severity_levels,
        vulnerability_states: rule.vulnerability_states,
        security_orchestration_policy_configuration_id: rule.security_orchestration_policy_configuration_id,
        scan_result_policy_id: rule.scan_result_policy_id,
        applicable_post_merge: rule.applicable_post_merge,
        project_id: rule.project_id,
        approval_policy_rule_id: rule.approval_policy_rule_id,
        updated_at: rule.updated_at,
        created_at: rule.created_at
      })
    end
  end

  describe '#applicable_to_branch?' do
    let!(:rule) { create(:approval_merge_request_rule, merge_request: merge_request) }
    let(:branch) { 'stable' }

    subject { rule.applicable_to_branch?(branch) }

    shared_examples_for 'with applicable rules to specified branch' do
      it { is_expected.to be_truthy }
    end

    context 'with approval policy branch exceptions' do
      let_it_be(:security_policy) { build(:security_policy) }
      let_it_be(:approval_policy_rule) do
        build(:approval_policy_rule, :scan_finding, security_policy: security_policy)
      end

      let_it_be(:rule) do
        build(:approval_merge_request_rule, merge_request: merge_request, approval_policy_rule: approval_policy_rule)
      end

      before do
        security_policy.content[:bypass_settings] = {
          branches: [{
            source: { name: merge_request.source_branch }, target: { name: merge_request.target_branch }
          }]
        }
      end

      it 'returns false' do
        expect(rule.applicable_to_branch?(branch)).to be_falsey
      end
    end

    context 'when there are no associated source rules' do
      it_behaves_like 'with applicable rules to specified branch'
    end

    describe 'policy target branch matching' do
      let!(:source_rule) { create(:approval_project_rule, project: merge_request.target_project, approval_policy_rule: approval_policy_rule) }
      let!(:rule) { create(:approval_merge_request_rule, approval_project_rule: source_rule, merge_request: merge_request, approval_policy_rule: approval_policy_rule) }

      before do
        merge_request.update!(target_branch: "release/staging")

        source_rule.protected_branches = [create(:protected_branch, project: merge_request.project, name: "release/*")]
        source_rule.save!
      end

      subject(:applies?) { rule.applicable_to_branch?(merge_request.target_branch) }

      context 'with `branches`' do
        let(:approval_policy_rule) do
          build(:approval_policy_rule, :scan_finding) do |policy_rule|
            policy_rule.update!(content: policy_rule.content.merge("branches" => branches))
          end
        end

        context 'with matching branch specification' do
          let(:branches) { ["release/staging"] }

          it { is_expected.to be(true) }
        end

        context 'with matching branch specification' do
          let(:branches) { ["master", "release/staging"] }

          it { is_expected.to be(true) }
        end

        context 'with matching branch specification' do
          let(:branches) { ["release/*"] }

          it { is_expected.to be(true) }
        end

        context 'with mismatching branch specification' do
          let(:branches) { ["release/production"] }

          it { is_expected.to be(false) }

          context 'with feature disabled' do
            before do
              stub_feature_flags(merge_request_approval_policies_target_branch_matching: false)
            end

            it { is_expected.to be(true) }
          end
        end
      end

      context 'with `branch_type`' do
        let(:approval_policy_rule) do
          build(:approval_policy_rule, :scan_finding) do |policy_rule|
            policy_rule.update!(content: policy_rule.content.excluding("branches").merge("branch_type" => branch_type))
          end
        end

        context 'with `default` branch type' do
          let(:branch_type) { 'default' }

          before do
            allow(merge_request.project).to receive(:default_branch).and_return(default_branch)
          end

          context 'when MR targets default branch' do
            let(:default_branch) { "release/staging" }

            it { is_expected.to be(true) }
          end

          context 'when MR does not target default branch' do
            let(:default_branch) { "release/production" }

            it { is_expected.to be(false) }

            context 'with feature disabled' do
              before do
                stub_feature_flags(merge_request_approval_policies_target_branch_matching: false)
              end

              it { is_expected.to be(true) }
            end
          end
        end
      end
    end

    context 'when there are associated source rules' do
      let!(:source_rule) { create(:approval_project_rule, project: merge_request.target_project) }
      let!(:rule) { create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: source_rule) }

      context 'and rule is not modified_from_project_rule' do
        before do
          rule.update!(
            name: source_rule.name,
            approvals_required: source_rule.approvals_required,
            users: source_rule.users,
            groups: source_rule.groups
          )
        end

        context 'and there are no associated protected branches to source rule' do
          it_behaves_like 'with applicable rules to specified branch'
        end

        context 'and there are associated protected branches to source rule' do
          before do
            source_rule.update!(protected_branches: protected_branches)
          end

          context 'and branch matches' do
            let(:protected_branches) { Array.new(1) { create(:protected_branch, name: branch, project: project) } }

            it_behaves_like 'with applicable rules to specified branch'
          end

          context 'and branch does not match anything' do
            let(:protected_branches) { Array.new(1) { create(:protected_branch, name: branch.reverse, project: project) } }

            it { is_expected.to be_falsey }
          end
        end
      end

      context 'and rule is modified_from_project_rule' do
        before do
          rule.update!(name: 'Overridden Rule')
        end

        it_behaves_like 'with applicable rules to specified branch'
      end

      context 'and rule is overridden but not modified_from_project_rule' do
        let!(:rule) { create(:approval_merge_request_rule, name: 'test', merge_request: merge_request, approval_project_rule: source_rule) }

        it_behaves_like 'with applicable rules to specified branch'

        context 'and protected branches exist but branch does not match anything' do
          let(:protected_branches) { Array.new(1) { create(:protected_branch, name: branch.reverse, project: project) } }

          before do
            source_rule.update!(protected_branches: protected_branches)
          end

          it 'does not find applicable rules' do
            expect(subject).to be_falsey
          end
        end
      end
    end
  end

  context 'with loose foreign key on approval_merge_request_rules.approval_policy_rule_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:approval_policy_rule) }
      let_it_be(:model) { create(:approval_merge_request_rule, approval_policy_rule: parent) }
    end
  end
end
