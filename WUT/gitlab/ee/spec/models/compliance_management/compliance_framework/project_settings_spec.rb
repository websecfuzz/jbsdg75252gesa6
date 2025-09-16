# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectSettings, type: :model,
  feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: sub_group) }

  subject { build(:compliance_framework_project_setting, project: project) }

  describe 'Associations' do
    it 'belongs to project' do
      expect(subject).to belong_to(:project)
    end
  end

  describe 'Validations' do
    it 'confirms the presence of project' do
      expect(subject).to validate_presence_of(:project)
    end

    describe '#frameworks_count_per_project' do
      context 'when frameworks count is one less than max count' do
        before do
          19.times do |i|
            create(:compliance_framework_project_setting, project: project,
              compliance_management_framework: create(:compliance_framework, namespace: group, name: "Test#{i}"))
          end
        end

        it 'creates setting with no error' do
          expect(subject.valid?).to eq(true)
          expect(subject.errors).to be_empty
        end
      end

      context 'when frameworks count is equal to max count' do
        before do
          20.times do |i|
            create(:compliance_framework_project_setting, project: project,
              compliance_management_framework: create(:compliance_framework, namespace: group, name: "Test#{i}"))
          end
        end

        it 'returns error' do
          expect(subject.valid?).to eq(false)
          expect(subject.errors.full_messages).to contain_exactly("Project cannot have more than 20 frameworks")
        end
      end
    end
  end

  describe 'scopes' do
    let_it_be(:framework1) do
      create(:compliance_framework, namespace: project.group.root_ancestor, name: 'framework1')
    end

    let_it_be(:setting) do
      create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework1)
    end

    describe '.by_framework_and_project' do
      it 'returns the setting' do
        expect(described_class.by_framework_and_project(project.id, framework1.id))
          .to eq([setting])
      end
    end

    describe '.by_project_id' do
      it 'returns the setting' do
        expect(described_class.by_project_id(project.id)).to eq([setting])
      end
    end
  end

  describe 'creation of ComplianceManagement::Framework record' do
    subject { create(:compliance_framework_project_setting, :sox, project: project) }

    it 'creates a new record' do
      expect(subject.reload.compliance_management_framework.name).to eq('SOX')
    end
  end

  describe 'set a custom ComplianceManagement::Framework' do
    let(:framework) { create(:compliance_framework, name: 'my framework') }

    it 'assigns the framework' do
      subject.compliance_management_framework = framework
      subject.save!

      expect(subject.compliance_management_framework.name).to eq('my framework')
    end
  end

  describe '.find_or_create_by_project' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:new_framework) { create(:compliance_framework, namespace: group, name: 'New Framework') }

    subject(:assign_framework) { described_class.find_or_create_by_project(project, new_framework) }

    context 'when there is no compliance framework assigned to a project', :freeze_time do
      it 'creates a new record' do
        expect { assign_framework }.to change { described_class.count }.by(1)
      end

      it 'creates the compliance framework project settings with correct framework' do
        setting = assign_framework

        expect(setting.project).to eq(project)
        expect(setting.framework_id).to eq(new_framework.id)
      end

      it 'sets created_at when creating a new record' do
        setting = assign_framework

        expect(setting.created_at).to eq(Time.current)
      end
    end

    context 'when there is a compliance framework assigned to a project' do
      let_it_be(:old_framework) { create(:compliance_framework, namespace: group, name: 'Existing Framework') }
      let_it_be(:existing_setting) do
        create(:compliance_framework_project_setting,
          project: project,
          compliance_management_framework: old_framework)
      end

      it 'does not create a new record' do
        expect { assign_framework }.not_to change { described_class.count }
      end

      it 'updates the compliance framework project settings' do
        expect(existing_setting.framework_id).to eq(old_framework.id)

        setting = described_class.find_or_create_by_project(project, new_framework)
        setting.reload

        expect(setting.id).to eq(existing_setting.id)
        expect(setting.project_id).to eq(project.id)
        expect(setting.framework_id).to eq(new_framework.id)
      end

      it 'does not update the created_at timestamp' do
        original_timestamp = existing_setting.created_at

        travel_to(1.day.from_now) do
          setting = assign_framework

          expect(setting.created_at.to_i).to eq(original_timestamp.to_i)
        end
      end
    end
  end

  describe '.covered_projects_count' do
    let_it_be(:framework1) { create(:compliance_framework, namespace: group, name: "framework 1") }
    let_it_be(:framework2) { create(:compliance_framework, namespace: group, name: "framework 2") }

    let_it_be(:project1) { create(:project, group: group) }
    let_it_be(:project2) { create(:project, group: group) }
    let_it_be(:project3) { create(:project, group: group) }
    let_it_be(:project4) { create(:project, group: group) }

    context 'when some projects have frameworks assigned' do
      before_all do
        create(:compliance_framework_project_setting,
          project: project1,
          compliance_management_framework: framework1)
        create(:compliance_framework_project_setting,
          project: project2,
          compliance_management_framework: framework1)
      end

      it 'returns the count of projects with at least one framework' do
        project_ids = [project1.id, project2.id, project3.id]
        expect(described_class.covered_projects_count(project_ids)).to eq(2)
      end
    end

    context 'when a project has multiple frameworks assigned' do
      before_all do
        create(:compliance_framework_project_setting,
          project: project1,
          compliance_management_framework: framework1)
        create(:compliance_framework_project_setting,
          project: project1,
          compliance_management_framework: framework2)
        create(:compliance_framework_project_setting,
          project: project2,
          compliance_management_framework: framework1)
      end

      it 'counts each project only once' do
        project_ids = [project1.id, project2.id, project3.id]
        expect(described_class.covered_projects_count(project_ids)).to eq(2)
      end
    end

    context 'when passing an empty array of project_ids' do
      it 'returns 0' do
        expect(described_class.covered_projects_count([])).to eq(0)
      end
    end

    context 'when passing project_ids that do not exist in settings' do
      let_it_be(:setting1) do
        create(:compliance_framework_project_setting,
          project: project1,
          compliance_management_framework: framework1)
      end

      it 'returns 0 for non-existent projects' do
        non_existent_ids = [non_existing_record_id]

        expect(described_class.covered_projects_count(non_existent_ids)).to eq(0)
      end
    end
  end
end
