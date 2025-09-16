# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirement,
  type: :model, feature_category: :compliance_management do
  describe 'validations' do
    let_it_be(:group) { create(:group) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: group) }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework) }

    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:framework_id) }
    it { is_expected.to validate_presence_of(:namespace_id) }
    it { is_expected.to validate_presence_of(:framework) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(500) }

    describe '#requirements_count_per_framework' do
      let_it_be(:compliance_framework_1) { create(:compliance_framework, :sox, namespace: group) }

      subject(:new_compliance_requirement) { build(:compliance_requirement, framework: compliance_framework_1) }

      context 'when requirements count is one less than max count' do
        before do
          49.times do |i|
            create(:compliance_requirement, framework: compliance_framework_1, name: "Test#{i}")
          end
        end

        it 'creates requirement with no error' do
          expect(new_compliance_requirement.valid?).to eq(true)
          expect(new_compliance_requirement.errors).to be_empty
        end
      end

      context 'when requirements count is equal to max count' do
        before do
          50.times do |i|
            create(:compliance_requirement, framework: compliance_framework_1, name: "Test#{i}")
          end
        end

        it 'returns error' do
          expect(new_compliance_requirement.valid?).to eq(false)
          expect(new_compliance_requirement.errors.full_messages)
            .to contain_exactly("Framework cannot have more than 50 requirements")
        end
      end
    end

    describe '#framework_belongs_to_namespace' do
      let_it_be(:other_group) { create(:group) }

      context 'when compliance framework belongs to the same group' do
        subject(:build_requirement) do
          build(:compliance_requirement, framework: compliance_framework, namespace: group, name: 'requirement1')
        end

        it 'is valid' do
          expect(build_requirement).to be_valid
        end
      end

      context 'when compliance framework belongs to a different group' do
        subject(:build_requirement) do
          build(:compliance_requirement, framework: compliance_framework, namespace: other_group)
        end

        it 'is invalid' do
          expect(build_requirement).not_to be_valid
          expect(build_requirement.errors[:namespace]).to include("must be the same as the framework's namespace.")
        end
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:framework).optional(false) }
    it { is_expected.to belong_to(:namespace).optional(false) }
    it { is_expected.to have_many(:security_policy_requirements) }
    it { is_expected.to have_many(:compliance_framework_security_policies).through(:security_policy_requirements) }
    it { is_expected.to have_many(:compliance_requirements_controls) }
    it { is_expected.to have_many(:project_control_compliance_statuses) }
    it { is_expected.to have_many(:project_requirement_compliance_statuses) }
  end

  describe '#delete_compliance_requirements_controls' do
    let_it_be(:group) { create(:group) }
    let_it_be(:other_requirement) { create(:compliance_requirement) }
    let_it_be(:other_control) { create(:compliance_requirements_control, compliance_requirement: other_requirement) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:framework) { create(:compliance_framework, namespace: group) }

    let_it_be(:compliance_requirement) { create(:compliance_requirement, framework: framework) }
    let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: compliance_requirement) }
    let_it_be(:control2) do
      create(:compliance_requirements_control, :project_visibility_not_internal,
        compliance_requirement: compliance_requirement)
    end

    before do
      create(:project_control_compliance_status, compliance_requirement: compliance_requirement, project: project,
        compliance_requirements_control: control1)
      create(:project_control_compliance_status, compliance_requirement: compliance_requirement, project: project,
        compliance_requirements_control: control2)
    end

    context 'when there are associated controls' do
      it 'deletes all associated compliance_requirements_controls' do
        expect do
          compliance_requirement.delete_compliance_requirements_controls
        end.to change { compliance_requirement.compliance_requirements_controls.count }.from(2).to(0)
      end

      it 'deletes all project controls statuses belonging to the requirement' do
        expect do
          compliance_requirement.delete_compliance_requirements_controls
        end.to change { project.project_control_compliance_statuses.count }.from(2).to(0)
      end

      it 'does not delete any other compliance_requirements_controls' do
        expect do
          compliance_requirement.delete_compliance_requirements_controls
        end.not_to change { other_requirement.compliance_requirements_controls.count }
      end
    end

    context 'when there are no associated controls' do
      let_it_be(:requirement_without_controls) { create(:compliance_requirement) }

      it 'does not raise an error' do
        expect do
          requirement_without_controls.delete_compliance_requirements_controls
        end.not_to raise_error
      end
    end
  end

  describe '.for_framework' do
    let_it_be(:namespace) { create(:group) }

    let_it_be(:framework1) { create(:compliance_framework, namespace: namespace, name: 'framework1') }
    let_it_be(:framework2) { create(:compliance_framework, namespace: namespace, name: 'framework2') }
    let_it_be(:framework3) { create(:compliance_framework, namespace: namespace, name: 'framework3') }

    let_it_be(:requirement1) { create(:compliance_requirement, framework: framework1, namespace: namespace) }
    let_it_be(:requirement2) { create(:compliance_requirement, framework: framework1, namespace: namespace) }
    let_it_be(:requirement3) { create(:compliance_requirement, framework: framework2, namespace: namespace) }

    context 'when framework has requirements' do
      it 'only returns compliance requirement ids for that framework' do
        expect(described_class.for_framework(framework1.id)).to contain_exactly(
          requirement1, requirement2)
      end
    end

    context 'when framework does not have requirements' do
      it 'returns empty array' do
        expect(described_class.for_framework(framework3)).to be_empty
      end
    end
  end
end
