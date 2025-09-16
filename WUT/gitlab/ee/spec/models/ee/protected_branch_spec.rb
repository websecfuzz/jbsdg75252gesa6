# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranch, feature_category: :source_code_management do
  subject(:protected_branch) { create(:protected_branch) }

  let(:project) { subject.project }
  let(:user) { create(:user) }

  it_behaves_like 'protected ref with ee access levels for', :merge
  it_behaves_like 'protected ref with ee access levels for', :push
  it_behaves_like 'protected ref with access levels for', :unprotect
  it_behaves_like 'protected ref with ee access levels for', :unprotect

  describe 'associations' do
    it { is_expected.to have_many(:unprotect_access_levels).inverse_of(:protected_branch) }
    it { is_expected.to have_many(:required_code_owners_sections).class_name('ProtectedBranch::RequiredCodeOwnersSection') }
    it { is_expected.to have_and_belong_to_many(:approval_project_rules) }

    it do
      is_expected
        .to have_and_belong_to_many(:external_status_checks)
        .class_name('::MergeRequests::ExternalStatusCheck')
    end

    it { is_expected.to have_one(:squash_option) }
    it { is_expected.to have_one(:merge_request_approval_setting) }
    it { is_expected.to accept_nested_attributes_for(:squash_option) }
  end

  shared_examples 'uniqueness validation' do |access_level_class|
    let(:factory_name) { access_level_class.to_s.underscore.sub('/', '_').to_sym }
    let(:association_name) { access_level_class.to_s.underscore.sub('protected_branch/', '').pluralize.to_sym }

    human_association_name = access_level_class.to_s.underscore.humanize.sub('Protected branch/', '')

    context "while checking uniqueness of a role-based #{human_association_name}" do
      it "allows a single #{human_association_name} for a role (per protected branch)" do
        first_protected_branch = create(:protected_branch, default_access_level: false)
        second_protected_branch = create(:protected_branch, default_access_level: false)

        first_protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)
        second_protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)

        expect(first_protected_branch).to be_valid
        expect(second_protected_branch).to be_valid

        first_protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)
        expect(first_protected_branch).to be_invalid
        expect(first_protected_branch.errors.full_messages.first).to match("access level has already been taken")
      end

      it "does not count a user-based #{human_association_name} with an `access_level` set" do
        protected_branch = create(:protected_branch, default_access_level: false)
        protected_branch.project.add_developer(user)

        protected_branch.send(association_name) << build(factory_name, user: user, access_level: Gitlab::Access::MAINTAINER)
        protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)

        expect(protected_branch).to be_valid
      end

      it "does not count a group-based #{human_association_name} with an `access_level` set" do
        group = create(:group)
        protected_branch = create(:protected_branch, default_access_level: false)
        protected_branch.project.project_group_links.create!(group: group)

        protected_branch.send(association_name) << build(factory_name, group: group, access_level: Gitlab::Access::MAINTAINER)
        protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)

        expect(protected_branch).to be_valid
      end
    end

    context "while checking uniqueness of a user-based #{human_association_name}" do
      it "allows a single #{human_association_name} for a user (per protected branch)" do
        first_protected_branch = create(:protected_branch, default_access_level: false)
        second_protected_branch = create(:protected_branch, default_access_level: false)

        first_protected_branch.project.add_developer(user)
        second_protected_branch.project.add_developer(user)

        first_protected_branch.send(association_name) << build(factory_name, user: user)
        second_protected_branch.send(association_name) << build(factory_name, user: user)

        expect(first_protected_branch).to be_valid
        expect(second_protected_branch).to be_valid

        first_protected_branch.send(association_name) << build(factory_name, user: user)
        expect(first_protected_branch).to be_invalid
        expect(first_protected_branch.errors.full_messages.first).to match("user has already been taken")
      end

      it "ignores the `access_level` while validating a user-based #{human_association_name}" do
        protected_branch = create(:protected_branch, default_access_level: false)
        protected_branch.project.add_developer(user)

        protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)
        protected_branch.send(association_name) << build(factory_name, user: user, access_level: Gitlab::Access::MAINTAINER)

        expect(protected_branch).to be_valid
      end
    end

    context "while checking uniqueness of a group-based #{human_association_name}" do
      let(:group) { create(:group) }

      it "allows a single #{human_association_name} for a group (per protected branch)" do
        first_protected_branch = create(:protected_branch, default_access_level: false)
        second_protected_branch = create(:protected_branch, default_access_level: false)

        first_protected_branch.project.project_group_links.create!(group: group)
        second_protected_branch.project.project_group_links.create!(group: group)

        first_protected_branch.send(association_name) << build(factory_name, group: group)
        second_protected_branch.send(association_name) << build(factory_name, group: group)

        expect(first_protected_branch).to be_valid
        expect(second_protected_branch).to be_valid

        first_protected_branch.send(association_name) << build(factory_name, group: group)
        expect(first_protected_branch).to be_invalid
        expect(first_protected_branch.errors.full_messages.first).to match("group has already been taken")
      end

      it "ignores the `access_level` while validating a group-based #{human_association_name}" do
        protected_branch = create(:protected_branch, default_access_level: false)
        protected_branch.project.project_group_links.create!(group: group)

        protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)
        protected_branch.send(association_name) << build(factory_name, group: group, access_level: Gitlab::Access::MAINTAINER)

        expect(protected_branch).to be_valid
      end
    end
  end

  it_behaves_like 'uniqueness validation', ProtectedBranch::MergeAccessLevel
  it_behaves_like 'uniqueness validation', ProtectedBranch::PushAccessLevel

  describe 'squash options validation' do
    context 'when squash options are being created' do
      before do
        protected_branch.squash_option_attributes = { project: project, protected_branch: protected_branch }
      end

      context 'and name also changes to wildcard' do
        before do
          protected_branch.name = '*'
        end

        it 'is invalid' do
          expect(protected_branch).to be_invalid
          expect(protected_branch.errors.full_messages).to match_array([
            'Squash option protected branch cannot be a wildcard'
          ])
        end
      end
    end

    context 'when squash options exist' do
      let!(:squash_option) { create :branch_rule_squash_option, project: project, protected_branch: protected_branch }

      context 'and name changes to wildcard' do
        before do
          protected_branch.name = '*'
        end

        it 'is invalid' do
          expect(protected_branch).to be_invalid
          expect(protected_branch.errors.full_messages).to match_array([
            'Squash option can only be configured for exact match branch rules'
          ])
        end
      end
    end
  end

  describe "#code_owner_approval_required" do
    context "when the attr code_owner_approval_required is true" do
      let(:subject_branch) { create(:protected_branch, code_owner_approval_required: true) }

      it "returns true" do
        expect(subject_branch.project)
          .to receive(:code_owner_approval_required_available?).once.and_return(true)
        expect(subject_branch.code_owner_approval_required).to be_truthy
      end

      it "returns false when the project doesn't require approvals" do
        expect(subject_branch.project)
          .to receive(:code_owner_approval_required_available?).once.and_return(false)
        expect(subject_branch.code_owner_approval_required).to be_falsy
      end
    end

    context "when the attr code_owner_approval_required is false" do
      let(:subject_branch) { create(:protected_branch, code_owner_approval_required: false) }

      it "returns false" do
        expect(subject_branch.code_owner_approval_required).to be_falsy
      end
    end
  end

  describe '#can_unprotect?' do
    let(:admin) { create(:user, :admin) }
    let(:maintainer) do
      create(:user, maintainer_of: project)
    end

    context 'without unprotect_access_levels' do
      it "doesn't add any additional restriction" do
        expect(subject.can_unprotect?(user)).to eq true
      end
    end

    context 'with access level set to MAINTAINER' do
      before do
        subject.unprotect_access_levels.create!(access_level: Gitlab::Access::MAINTAINER)
      end

      it 'prevents access to users' do
        expect(subject.can_unprotect?(user)).to eq(false)
      end

      it 'grants access to maintainers' do
        expect(subject.can_unprotect?(maintainer)).to eq(true)
      end

      it 'prevents access to admins' do
        expect(subject.can_unprotect?(admin)).to eq(false)
      end
    end

    context 'with access level set to ADMIN' do
      before do
        subject.unprotect_access_levels.create!(access_level: Gitlab::Access::ADMIN)
      end

      it 'prevents access to maintainers' do
        expect(subject.can_unprotect?(maintainer)).to eq(false)
      end

      it 'grants access to admins' do
        expect(subject.can_unprotect?(admin)).to eq(true)
      end
    end

    context 'multiple access levels' do
      before do
        project.add_developer(user)
        subject.unprotect_access_levels.create!(user: maintainer)
        subject.unprotect_access_levels.create!(user: user)
      end

      it 'grants access if any grant access' do
        expect(subject.can_unprotect?(user)).to eq true
      end
    end
  end

  describe '.branch_requires_code_owner_approval?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let(:branch_name) { "BRANCH_NAME" }

    before do
      allow(project).to receive(:code_owner_approval_required_available?).and_return(true)
    end

    subject { described_class.branch_requires_code_owner_approval?(project, branch_name) }

    context 'when there are no match branches' do
      it { is_expected.to eq(false) }
    end

    context 'when `code_owner_approval_required_available?` of project is false' do
      before do
        allow(project).to receive(:code_owner_approval_required_available?).and_return(false)
      end

      it { is_expected.to eq(false) }
    end

    context 'when there are matched branches' do
      using RSpec::Parameterized::TableSyntax

      where(:object, :code_owner_approval_required, :result) do
        ref(:project)         | false        | false
        ref(:project)         | true         | true
        ref(:group)           | false        | false
        ref(:group)           | true         | true
      end

      with_them do
        before do
          params = object.is_a?(Project) ? { project: object } : { project: nil, group: object }

          create(:protected_branch, name: branch_name, code_owner_approval_required: code_owner_approval_required, **params)
        end

        it { is_expected.to eq(result) }
      end
    end

    context 'when there are matched branches - quarantined examples',
      quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/470328' do
      using RSpec::Parameterized::TableSyntax

      where(:object, :code_owner_approval_required, :result) do
        ref(:group) | true | true
      end

      with_them do
        before do
          params = object.is_a?(Project) ? { project: object } : { project: nil, group: object }

          create(:protected_branch, name: branch_name, code_owner_approval_required: code_owner_approval_required, **params)
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe '#inherited?' do
    context 'when the `namespace_id` is nil' do
      before do
        subject.assign_attributes(namespace_id: nil)
      end

      it { is_expected.not_to be_inherited }
    end

    context 'when the `namespace_id` is present' do
      before do
        subject.assign_attributes(namespace_id: 123)
      end

      it { is_expected.to be_inherited }
    end
  end

  describe '#supports_unprotection_restrictions?' do
    subject(:supports_unprotection_restrictions) { protected_branch.supports_unprotection_restrictions? }

    context 'when the `namespace_id` is nil' do
      before do
        protected_branch.assign_attributes(namespace_id: nil)
      end

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(unprotection_restrictions: false)
        end

        it { is_expected.to be_falsey }

        it 'does not load group without a reason' do
          expect { subject }.not_to exceed_query_limit(0)
        end
      end

      context 'when feature is licensed' do
        before do
          stub_licensed_features(unprotection_restrictions: true)
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when the `namespace_id` is present' do
      before do
        protected_branch.assign_attributes(namespace_id: 123)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#allow_force_push' do
    context 'when is not protected from push by security policy' do
      context 'when the `allow_force_push` is true' do
        before do
          subject.assign_attributes(allow_force_push: true)
        end

        it { is_expected.to be_allow_force_push }
      end

      context 'when the `allow_force_push` is false' do
        before do
          subject.assign_attributes(allow_force_push: false)
        end

        it { is_expected.not_to be_allow_force_push }
      end
    end

    context 'when is protected from push by security policy and the `allow_force_push` is true' do
      before do
        subject.assign_attributes(allow_force_push: true)
        allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ProtectedBranchesPushService) do |service|
          allow(service).to receive(:execute).and_return([protected_branch.name])
        end
      end

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it { is_expected.to be_allow_force_push }
      end

      context 'when feature is licensed' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        context 'when protected branch is created on group level' do
          let_it_be(:group) { create(:group) }

          before do
            subject.assign_attributes(group: group)
          end

          it { is_expected.to be_allow_force_push }
        end

        context 'when protected branch is created on project level' do
          it { is_expected.not_to be_allow_force_push }
        end
      end
    end
  end

  describe '#modification_blocked_by_policy?' do
    subject(:result) { protected_branch.modification_blocked_by_policy? }

    before do
      project.repository.add_branch(project.creator, branch_name, 'HEAD')
    end

    context 'with project-level protected branch' do
      let(:project) { create(:project, :repository) }
      let(:protected_branch) { create(:protected_branch, project: project) }
      let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

      context 'without blocking approval policy' do
        let(:approval_policies) { [] }

        it { is_expected.to be(false) }
      end

      include_context 'with approval policy blocking protected branches' do
        let(:branch_name) { protected_branch.name }

        it { is_expected.to be(true) }

        context 'without feature available' do
          before do
            stub_licensed_features(security_orchestration_policies: false)
          end

          it { is_expected.to be(false) }
        end

        context 'with mismatching name' do
          let(:branch_name) { protected_branch.name.reverse }

          it { is_expected.to be(false) }
        end

        context 'when protected branch is not backed by git ref' do
          before do
            project.repository.delete_branch(branch_name)
          end

          after do
            project.repository.add_branch(project.creator, branch_name, 'HEAD')
          end

          it { is_expected.to be(true) }
        end
      end
    end

    context 'with group-level protected branch' do
      let(:group) { create(:group) }
      let(:project) { create(:project, :repository, group: group) }
      let(:protected_branch) { create(:protected_branch, :group_level, group: group) }
      let(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, namespace: group) }

      context 'without blocking approval policy' do
        let(:approval_policies) { [] }

        it { is_expected.to be(false) }
      end

      include_context 'with approval policy blocking group-level protected branches' do
        let(:branch_name) { protected_branch.name }

        it { is_expected.to be(true) }

        context 'without feature available' do
          before do
            stub_licensed_features(security_orchestration_policies: false)
          end

          it { is_expected.to be(false) }
        end
      end

      context 'when excepted' do
        let(:approval_policy) do
          build(:approval_policy,
            branch_type: 'protected',
            approval_settings: { block_group_branch_modification: { enabled: true, exceptions: [{ id: group.id }] } })
        end

        it { is_expected.to be(false) }
      end
    end
  end
end
