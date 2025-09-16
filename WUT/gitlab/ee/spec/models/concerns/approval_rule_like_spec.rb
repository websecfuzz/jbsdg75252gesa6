# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRuleLike, feature_category: :source_code_management do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:group1) { create(:group) }
  let(:group2) { create(:group) }

  let(:merge_request) { create(:merge_request) }

  let(:subject_traits) { [] }

  shared_examples 'approval rule like' do
    let(:group1_user) { create(:user) }
    let(:group2_user) { create(:user) }

    before do
      subject.users << user1
      subject.users << user2
      subject.groups << group1
      subject.groups << group2

      group1.add_guest(group1_user)
      group2.add_guest(group2_user)
    end

    it { is_expected.to respond_to(:rule_project) }

    describe '#approvers_include_user?' do
      let(:rule) { subject.class.find(subject.id) }

      it 'returns true for a contained user' do
        expect(rule.approvers_include_user?(user1)).to be_truthy
      end

      it 'returns true for a group user' do
        expect(rule.approvers_include_user?(group1_user)).to be_truthy
      end

      it 'returns false for a missing user' do
        expect(rule.approvers_include_user?(user3)).to be_falsey
      end

      context 'when the user relations are already loaded' do
        it 'returns true for a contained user' do
          rule.users.to_a

          expect(rule.approvers_include_user?(user1)).to be_truthy
        end

        it 'returns true for a group user' do
          rule.group_members.to_a

          expect(rule.approvers_include_user?(group1_user)).to be_truthy
        end

        it 'returns false for a missing user' do
          rule.users.to_a

          expect(rule.approvers_include_user?(user3)).to be_falsey
        end
      end

      context 'when dealing with team members and custom roles' do
        let_it_be(:group) { create(:group) }
        let_it_be(:group_project) { create(:project, group: group) }
        let_it_be(:custom_role) { create(:member_role, :instance, :admin_merge_request) }
        let_it_be(:team_member_with_role) { create(:user) }
        let_it_be(:team_member_without_role) { create(:user) }
        let_it_be(:scan_result_policy_read) do
          create(:scan_result_policy_read, custom_roles: [custom_role.id])
        end

        before do
          project = rule.project
          project.update!(group: group)

          rule.update!(scan_result_policy_read: scan_result_policy_read)

          create(:group_member, member_role: custom_role, user: team_member_with_role, group: group)
          create(:group_member, :developer, user: team_member_without_role, group: group)
        end

        context 'when scan_result_policy_read is nil' do
          before do
            rule.update!(scan_result_policy_read: nil)
          end

          it 'returns false' do
            expect(rule.approvers_include_user?(team_member_with_role)).to be_falsey
            expect(rule.approvers_include_user?(team_member_without_role)).to be_falsey
          end
        end

        context 'for a team member with the custom role' do
          it 'returns true when user belongs to custom role and false otherwise' do
            expect(rule.approvers_include_user?(team_member_with_role)).to be_truthy
            expect(rule.approvers_include_user?(team_member_without_role)).to be_falsey
          end
        end

        it 'returns false for a team member without the custom role' do
          expect(rule.approvers_include_user?(team_member_without_role)).to be_falsey
        end

        it 'returns false for a user who is not a team member' do
          non_team_member = create(:user)
          expect(rule.approvers_include_user?(non_team_member)).to be_falsey
        end

        context 'when the user relations are already loaded' do
          context 'for a team member with the custom role' do
            it 'returns true when user belongs to custom role and false otherwise' do
              rule.users.to_a
              rule.group_members.to_a

              expect(rule.approvers_include_user?(team_member_with_role)).to be_truthy
              expect(rule.approvers_include_user?(team_member_without_role)).to be_falsey
            end
          end

          it 'returns false for a team member without the custom role' do
            rule.users.to_a
            rule.group_members.to_a

            expect(rule.approvers_include_user?(team_member_without_role)).to be_falsey
          end
        end
      end
    end

    describe '#approvers' do
      shared_examples 'approvers contains the right users' do
        it 'contains users as direct members and group members' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1, user2, group1_user, group2_user)
        end

        context 'when some users are inactive' do
          before do
            user2.block!
            group2_user.block!
          end

          it 'returns users that are only active' do
            rule = subject.class.find(subject.id)

            expect(rule.approvers).to contain_exactly(user1, group1_user)
          end
        end
      end

      it_behaves_like 'approvers contains the right users'

      context 'when the user relations are already loaded' do
        before do
          subject.users.to_a
          subject.group_users.to_a
        end

        it 'does not perform any new queries when all users are loaded already' do
          # single query is triggered for license check
          expect { subject.approvers }.not_to exceed_query_limit(1)
        end

        it_behaves_like 'approvers contains the right users'
      end

      context 'when user is both a direct member and a group member' do
        before do
          group1.add_guest(user1)
          group2.add_guest(user2)
        end

        it 'contains only unique users' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1, user2, group1_user, group2_user)
        end
      end

      context 'when scan_result_policy_read has role_approvers' do
        let_it_be(:user4) { create(:user) }
        let_it_be(:scan_result_policy_read) do
          create(:scan_result_policy_read, role_approvers: [Gitlab::Access::MAINTAINER])
        end

        before do
          subject.update!(scan_result_policy_read: scan_result_policy_read)
          group1.add_maintainer(user4)
        end

        it 'contains users as direct members and group members and role members' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1, user2, group1_user, group2_user, user4)
        end
      end
    end

    describe '#from_scan_result_policy?' do
      context 'when report_type is scan_finding' do
        let(:subject_traits) { %i[scan_finding] }

        it 'returns true' do
          expect(subject.from_scan_result_policy?).to eq(true)
        end
      end

      context 'when report_type is license_scanning' do
        let(:subject_traits) { %i[license_scanning] }

        it 'returns true' do
          expect(subject.from_scan_result_policy?).to eq(true)
        end
      end

      context 'when report_type is any_merge_request' do
        let(:subject_traits) { %i[any_merge_request] }

        it 'returns true' do
          expect(subject.from_scan_result_policy?).to eq(true)
        end
      end

      context 'when report_type is nil' do
        before do
          subject.update!(report_type: nil)
        end

        it 'returns false' do
          expect(subject.from_scan_result_policy?).to eq(false)
        end
      end
    end

    describe '#policy_name' do
      context 'when approval_policy_rule is not present' do
        it 'trims trailing digit coming from multiple rules belonging to the same policy' do
          subject.update!(name: 'Policy 1')
          expect(subject.policy_name).to eq('Policy')
        end
      end

      context 'when approval_policy_rule is present' do
        let_it_be(:approval_policy_rule) { create(:approval_policy_rule) }
        let_it_be(:security_policy) { approval_policy_rule.security_policy }
        let_it_be(:policy_configuration) { security_policy.security_orchestration_policy_configuration }

        it 'gets name from security_policy' do
          subject.update!(scan_result_policy_read: create(:scan_result_policy_read,
            orchestration_policy_idx: security_policy.policy_index,
            rule_idx: approval_policy_rule.rule_index,
            security_orchestration_policy_configuration: policy_configuration))
          subject.update!(security_orchestration_policy_configuration: policy_configuration)

          expect(subject.policy_name).to eq(security_policy.name)
        end
      end
    end

    describe 'validation' do
      context 'when value is too big' do
        it 'is invalid' do
          subject.approvals_required = described_class::APPROVALS_REQUIRED_MAX + 1

          expect(subject).to be_invalid
          expect(subject.errors.key?(:approvals_required)).to eq(true)
        end
      end

      context 'when value is within limit' do
        it 'is valid' do
          subject.approvals_required = described_class::APPROVALS_REQUIRED_MAX

          expect(subject).to be_valid
        end
      end

      context 'with rule_type set to report_approver' do
        before do
          subject.rule_type = :report_approver
        end

        it 'is invalid' do
          subject.report_type = nil
          expect(subject).not_to be_valid
        end
      end

      context 'when importing' do
        before do
          subject.importing = true
        end

        context 'when orchestration_policy_idx is not nil' do
          it 'is invalid' do
            subject.orchestration_policy_idx = 2

            expect(subject).to be_invalid
            expect(subject.errors.key?(:orchestration_policy_idx)).to eq(true)
          end
        end

        context 'when orchestration_policy_idx is nil' do
          it 'is valid' do
            subject.orchestration_policy_idx = nil

            expect(subject).to be_valid
          end
        end

        context 'when report type is nil' do
          it 'is valid' do
            subject.report_type = nil

            expect(subject).to be_valid
          end
        end

        context 'when report type is scan_finding' do
          it 'is invalid' do
            subject.report_type = :scan_finding

            expect(subject).to be_invalid
            expect(subject.errors).to have_key(:report_type)
          end
        end

        context 'when report type is license_scanning' do
          it 'is invalid' do
            subject.report_type = :license_scanning

            expect(subject).to be_invalid
            expect(subject.errors).to have_key(:report_type)
          end
        end

        context 'when report type is any_merge_request' do
          it 'is invalid' do
            subject.report_type = :any_merge_request

            expect(subject).to be_invalid
            expect(subject.errors).to have_key(:report_type)
          end
        end

        context 'when report type is code_coverage' do
          it 'is valid' do
            subject.report_type = :code_coverage
            subject.name = 'Coverage-Check'

            expect(subject).to be_valid
          end
        end
      end

      context 'name attribute' do
        it { is_expected.to validate_length_of(:name).is_at_most(described_class::NAME_LENGTH_LIMIT) }

        context 'when name is above the length limit' do
          it 'does not cause a validation error when the name is not changed' do
            # Modify the name in the database directly to bypass validations
            subject.class.where(id: subject.id).update_all(
              name: 'x' * (described_class::NAME_LENGTH_LIMIT + 10)
            )

            subject.reload
            expect(subject.name.length).to be > described_class::NAME_LENGTH_LIMIT

            subject.update!(approvals_required: described_class::APPROVALS_REQUIRED_MAX)
            expect(subject).to be_valid
          end
        end
      end
    end
  end

  context 'MergeRequest' do
    subject { create(:approval_merge_request_rule, *subject_traits, merge_request: merge_request) }

    it_behaves_like 'approval rule like'

    describe('#approvers') do
      context 'when role_approvers exist for codeowner rule' do
        subject { create(:code_owner_rule, *subject_traits, merge_request: merge_request) }

        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }
        let_it_be(:merge_request) { create(:merge_request, source_project: project) }
        let_it_be(:user1) { create(:user) }
        let_it_be(:user2) { create(:user) }
        let_it_be(:user3) { create(:user) }

        before_all do
          group.add_maintainer(user3)
          project.add_maintainer(user1)
          project.add_owner(user2)
        end

        before do
          subject.update!(role_approvers: [Gitlab::Access::MAINTAINER])
        end

        it 'contains role members' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1)
        end
      end
    end

    describe '#approvers_include_user?' do
      let(:rule) { subject.class.find(subject.id) }

      before do
        rule.update!(rule_type: 'code_owner', role_approvers: [Gitlab::Access::DEVELOPER])
        rule.project.add_developer(user1)
        rule.project.add_maintainer(user2)
      end

      it 'returns true for user within the selected roles' do
        expect(rule.approvers_include_user?(user1)).to be_truthy
      end

      it 'returns false for user not within the selected roles' do
        expect(rule.approvers_include_user?(user2)).to be_falsey
      end
    end

    describe '#overridden?' do
      it 'returns false' do
        expect(subject.overridden?).to be_falsy
      end

      context 'when rule has source rule' do
        let(:source_rule) do
          create(
            :approval_project_rule,
            project: merge_request.target_project,
            name: 'Source Rule',
            approvals_required: 2,
            users: [user1, user2],
            groups: [group1, group2]
          )
        end

        before do
          subject.update!(approval_project_rule: source_rule)
        end

        context 'and any attributes differ from source rule' do
          shared_examples_for 'overridden rule' do
            it 'returns true' do
              expect(subject.overridden?).to be_truthy
            end
          end

          context 'name' do
            before do
              subject.update!(name: 'Overridden Rule')
            end

            it_behaves_like 'overridden rule'
          end

          context 'approvals_required' do
            before do
              subject.update!(approvals_required: 1)
            end

            it_behaves_like 'overridden rule'
          end

          context 'users' do
            before do
              subject.update!(users: [user1])
            end

            it_behaves_like 'overridden rule'
          end

          context 'groups' do
            before do
              subject.update!(groups: [group1])
            end

            it_behaves_like 'overridden rule'
          end
        end

        context 'and no changes made to attributes' do
          before do
            subject.update!(
              name: source_rule.name,
              approvals_required: source_rule.approvals_required,
              users: source_rule.users,
              groups: source_rule.groups
            )
          end

          it 'returns false' do
            expect(subject.overridden?).to be_falsy
          end
        end
      end
    end
  end

  context 'Project' do
    subject { create(:approval_project_rule, *subject_traits) }

    it_behaves_like 'approval rule like'

    describe '#overridden?' do
      it 'returns false' do
        expect(subject.overridden?).to be_falsy
      end
    end
  end

  describe '.group_users' do
    subject { create(:approval_project_rule) }

    it 'returns distinct users' do
      group1.add_guest(user1)
      group2.add_guest(user1)
      subject.groups = [group1, group2]

      expect(subject.group_users).to eq([user1])
    end
  end

  describe '.exportable' do
    let_it_be(:project) { create(:project) }

    let_it_be(:any_approver_rule) { create(:approval_project_rule, :any_approver_rule, project: project) }
    let_it_be(:license_scanning_rule) { create(:approval_project_rule, :license_scanning, project: project) }
    let_it_be(:code_coverage) { create(:approval_project_rule, :code_coverage, project: project) }
    let_it_be(:scan_finding) { create(:approval_project_rule, :scan_finding, project: project) }
    let_it_be(:any_merge_request) { create(:approval_project_rule, :any_merge_request, project: project) }

    subject { project.approval_rules.exportable }

    it 'does not include rules created from scan result policies' do
      is_expected.to match_array([any_approver_rule, code_coverage])
    end
  end

  describe '.for_approval_policy_rules' do
    let_it_be(:project) { create(:project) }
    let_it_be(:security_policy) { create(:security_policy) }
    let_it_be(:other_security_policy) { create(:security_policy) }
    let_it_be(:policy_rule1) { create(:approval_policy_rule, security_policy: security_policy) }
    let_it_be(:policy_rule2) { create(:approval_policy_rule, security_policy: security_policy) }

    let_it_be(:approval_rule1) { create(:approval_project_rule, project: project, approval_policy_rule: policy_rule1) }
    let_it_be(:approval_rule2) { create(:approval_project_rule, project: project, approval_policy_rule: policy_rule2) }
    let_it_be(:approval_rule3) { create(:approval_project_rule, project: project, approval_policy_rule: nil) }

    it 'returns approval rules associated with the given policy rules' do
      result = project.approval_rules.for_approval_policy_rules(security_policy.approval_policy_rules)

      expect(result).to include(approval_rule1, approval_rule2)
      expect(result).not_to include(approval_rule3)
    end

    it 'returns empty when no matching policy rules exist' do
      result = project.approval_rules.for_approval_policy_rules(other_security_policy.approval_policy_rules)

      expect(result).to be_empty
    end

    it 'handles empty policy rules relation' do
      result = project.approval_rules.for_approval_policy_rules(Security::ApprovalPolicyRule.none)

      expect(result).to be_empty
    end

    it 'handles empty policy rules array' do
      result = project.approval_rules.for_approval_policy_rules([])

      expect(result).to be_empty
    end

    it 'returns approval rules associated with the given policy rules passed as array' do
      result = project.approval_rules.for_approval_policy_rules([policy_rule1, policy_rule2])

      expect(result).to include(approval_rule1, approval_rule2)
      expect(result).not_to include(approval_rule3)
    end
  end

  describe '.for_merge_requests' do
    let_it_be(:merge_request) { create(:merge_request) }
    let_it_be(:other_merge_request) { create(:merge_request) }

    let_it_be(:rule_1) { create(:approval_merge_request_rule, merge_request: merge_request) }
    let_it_be(:rule_2) { create(:approval_merge_request_rule, merge_request: merge_request) }
    let_it_be(:rule_3) { create(:approval_merge_request_rule, merge_request: build(:merge_request)) }

    it 'returns rules for the specified merge request' do
      result = ApprovalMergeRequestRule.for_merge_requests(merge_request.id)

      expect(result).to contain_exactly(rule_1, rule_2)
    end

    it 'returns empty when no rules match the merge request' do
      result = ApprovalMergeRequestRule.for_merge_requests(other_merge_request.id)

      expect(result).to be_empty
    end

    it 'supports multiple merge requests' do
      rule_4 = create(:approval_merge_request_rule, merge_request: other_merge_request)

      result = ApprovalMergeRequestRule.for_merge_requests([merge_request.id, other_merge_request.id])

      expect(result).to contain_exactly(rule_1, rule_2, rule_4)
    end
  end
  # rubocop:enable RSpec/FactoryBot/AvoidCreate
end
