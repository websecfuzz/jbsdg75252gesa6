# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Workflow, feature_category: :duo_workflow do
  let(:user) { create(:user) }
  let(:another_user) { create(:user) }
  let(:workflow) { create(:duo_workflows_workflow) }
  let(:owned_workflow) { create(:duo_workflows_workflow, user: user) }
  let(:not_owned_workflow) { create(:duo_workflows_workflow, user: another_user) }

  describe 'associations' do
    it { is_expected.to have_many(:checkpoints).class_name('Ai::DuoWorkflows::Checkpoint') }
    it { is_expected.to have_many(:checkpoint_writes).class_name('Ai::DuoWorkflows::CheckpointWrite') }
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:namespace).optional }
  end

  describe '.for_user_with_id!' do
    it 'finds the workflow for the given user and id' do
      expect(described_class.for_user_with_id!(user.id, owned_workflow.id)).to eq(owned_workflow)
    end

    it 'raises an error if the workflow is for a different user' do
      expect { described_class.for_user_with_id!(another_user, owned_workflow.id) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.for_user' do
    it 'finds the workflows for the given user' do
      expect(described_class.for_user(user)).to eq([owned_workflow])
    end
  end

  describe '.for_project' do
    let_it_be(:project) { create(:project) }
    let(:project_workflow) { create(:duo_workflows_workflow, project: project) }

    it 'finds the workflows for the given project' do
      expect(described_class.for_project(project)).to eq([project_workflow])
    end
  end

  describe '.with_environment' do
    let_it_be(:ide_workflow) { create(:duo_workflows_workflow, environment: :ide) }
    let_it_be(:web_workflow) { create(:duo_workflows_workflow, environment: :web) }

    it 'finds the local workflows when environment is ide' do
      expect(described_class.with_environment(:ide)).to eq([ide_workflow])
    end

    it 'finds the remote workflows when environment is web' do
      expect(described_class.with_environment(:web)).to eq([web_workflow])
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_length_of(:goal).is_at_most(16_384) }
    it { is_expected.to validate_length_of(:image).is_at_most(2048) }

    describe '#only_known_agent_priviliges' do
      it 'is valid with a valid privilege' do
        workflow = described_class.new(
          agent_privileges: [
            Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES
          ],
          pre_approved_agent_privileges: [],
          environment: :ide
        )
        expect(workflow).to be_valid
      end

      it 'is invalid with an invalid privilege' do
        workflow = described_class.new(agent_privileges: [999], environment: :ide)
        expect(workflow).not_to be_valid
        expect(workflow.errors[:agent_privileges]).to include("contains an invalid value 999")
      end
    end

    describe '.with_workflow_definition' do
      let!(:chat_workflow) { create(:duo_workflows_workflow, workflow_definition: 'chat') }
      let!(:dev_workflow) { create(:duo_workflows_workflow, workflow_definition: 'software_development') }

      it 'finds workflows with the given workflow definition' do
        expect(described_class.with_workflow_definition('chat')).to contain_exactly(chat_workflow)
        expect(described_class.with_workflow_definition('software_development')).to contain_exactly(dev_workflow)
      end

      it 'returns empty when no workflows match the definition' do
        expect(described_class.with_workflow_definition('nonexistent')).to be_empty
      end
    end

    describe '#only_known_pre_approved_agent_priviliges' do
      let(:agent_privileges) { [] }
      let(:pre_approved_agent_privileges) { [] }

      subject(:workflow) do
        described_class.new(
          agent_privileges: agent_privileges,
          pre_approved_agent_privileges: pre_approved_agent_privileges,
          environment: :ide
        )
      end

      it { is_expected.to be_valid }

      context 'with valid privilege' do
        let(:agent_privileges) { [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES] }
        let(:pre_approved_agent_privileges) { [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES] }

        it { is_expected.to be_valid }
      end

      context 'with invalid privilege' do
        let(:pre_approved_agent_privileges) { [999] }

        it 'is invalid' do
          is_expected.to be_invalid
          expect(workflow.errors[:pre_approved_agent_privileges]).to include("contains an invalid value 999")
        end
      end
    end

    describe '#pre_approved_privileges_included_in_agent_privileges' do
      using RSpec::Parameterized::TableSyntax
      let(:default_privileges) { Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES }
      let(:rw_files) { Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES }
      let(:ro_gitlab) { Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB }

      where(:pre_approved, :agent_privileges, :valid) do
        nil                               | nil                               | true
        []                                | []                                | true
        nil                               | []                                | false
        []                                | nil                               | true
        ref(:default_privileges)          | nil                               | true
        [ref(:ro_gitlab)]                 | [ref(:ro_gitlab)]                 | true
        [ref(:ro_gitlab)]                 | [ref(:rw_files), ref(:ro_gitlab)] | true
        [ref(:rw_files), ref(:ro_gitlab)] | [ref(:rw_files)]                  | false
      end

      with_them do
        specify do
          workflow = described_class
                       .new(
                         agent_privileges: agent_privileges,
                         pre_approved_agent_privileges: pre_approved,
                         environment: :ide
                       )

          expect(workflow.valid?).to eq(valid)
        end
      end
    end
  end

  describe '#agent_privileges' do
    it 'returns the privileges that are set' do
      workflow = described_class.new(
        agent_privileges: [
          Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
          Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
        ],
        pre_approved_agent_privileges: [],
        environment: :ide
      )

      # Validation triggers setting the default
      expect(workflow).to be_valid

      expect(workflow.agent_privileges).to match_array([
        described_class::AgentPrivileges::READ_WRITE_FILES,
        described_class::AgentPrivileges::READ_WRITE_GITLAB
      ])
    end

    it 'replaces with DEFAULT_PRIVILEGES when set to nil' do
      workflow = described_class.new(agent_privileges: nil, environment: :ide)

      # Validation triggers setting the default
      expect(workflow).to be_valid

      expect(workflow.agent_privileges).to match_array([
        described_class::AgentPrivileges::READ_WRITE_FILES,
        described_class::AgentPrivileges::READ_ONLY_GITLAB
      ])
    end

    it 'replaces with DEFAULT_PRIVILEGES when not set' do
      workflow = described_class.new(environment: :ide)

      # Validation triggers setting the default
      expect(workflow).to be_valid

      expect(workflow.agent_privileges).to match_array([
        described_class::AgentPrivileges::READ_WRITE_FILES,
        described_class::AgentPrivileges::READ_ONLY_GITLAB
      ])
    end
  end

  describe 'state transitions' do
    using RSpec::Parameterized::TableSyntax
    where(:status, :can_start, :can_pause, :can_resume, :can_finish, :can_drop, :can_stop, :can_retry,
      :can_require_input, :can_require_plan_approval, :can_require_tool_call_approval) do
      0 | true  | false | false | false | true  | true  | false | false | false | false
      1 | false | true  | false | true  | true  | true  | true  | true  | true  | true
      2 | false | false | true  | false | true  | true  | false | false | false | false
      3 | false | false | false | false | false | false | false | false | false | false
      4 | false | false | false | false | false | false | true  | false | false | false
      5 | false | false | false | false | false | false | true  | false | false | false
      6 | false | false | true  | false | true  | true  | false | false | false | false
      7 | false | false | true  | false | true  | true  | false | false | false | false
      8 | false | false | true  | false | true  | true  | false | false | false | false
    end

    with_them do
      it 'adheres to state machine rules', :aggregate_failures do
        owned_workflow.status = status

        expect(owned_workflow.can_start?).to eq(can_start)
        expect(owned_workflow.can_pause?).to eq(can_pause)
        expect(owned_workflow.can_resume?).to eq(can_resume)
        expect(owned_workflow.can_finish?).to eq(can_finish)
        expect(owned_workflow.can_drop?).to eq(can_drop)
        expect(owned_workflow.can_stop?).to eq(can_stop)
        expect(owned_workflow.can_retry?).to eq(can_retry)
        expect(owned_workflow.can_require_input?).to eq(can_require_input)
        expect(owned_workflow.can_require_plan_approval?).to eq(can_require_plan_approval)
        expect(owned_workflow.can_require_tool_call_approval?).to eq(can_require_tool_call_approval)
      end
    end
  end

  it 'has_many workloads' do
    workload1 = create(:ci_workload)
    workload2 = create(:ci_workload)
    create(:duo_workflows_workload, workflow: workflow, workload: workload1)
    create(:duo_workflows_workload, workflow: workflow, workload: workload2)

    expect(workflow.reload.workloads).to contain_exactly(workload1, workload2)
  end

  describe '#chat?' do
    subject { workflow.chat? }

    context 'when workflow_definition is chat' do
      let(:workflow) { build(:duo_workflows_workflow, workflow_definition: 'chat') }

      it { is_expected.to be_truthy }
    end

    context 'when workflow_definition is different from chat' do
      let(:workflow) { build(:duo_workflows_workflow, workflow_definition: 'awesome workflow') }

      it { is_expected.to be_falsey }
    end
  end

  describe '#project_level?' do
    subject { workflow.project_level? }

    context 'when project is present' do
      let(:workflow) { create(:duo_workflows_workflow, project: create(:project)) }

      it { is_expected.to be(true) }
    end

    context 'when namespace is present' do
      let(:workflow) { build(:duo_workflows_workflow, namespace: create(:group)) }

      it { is_expected.to be(false) }
    end
  end

  describe '#namespace_level?' do
    subject { workflow.namespace_level? }

    context 'when project is present' do
      let(:workflow) { create(:duo_workflows_workflow, project: create(:project)) }

      it { is_expected.to be(false) }
    end

    context 'when namespace is present' do
      let(:workflow) { build(:duo_workflows_workflow, namespace: create(:group)) }

      it { is_expected.to be(true) }
    end
  end

  describe '#mcp_enabled?' do
    subject { workflow.mcp_enabled? }

    let_it_be(:ai_settings) { create(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }

    context 'when project is present' do
      let(:project) { create(:project) }
      let(:workflow) { create(:duo_workflows_workflow, project: project) }

      it { is_expected.to be(false) }

      context 'when duo_workflow_mcp_enabled is enabled on root ancestor' do
        let(:group) { create(:group, ai_settings: ai_settings) }
        let(:project) { create(:project, group: group) }

        it { is_expected.to be(true) }
      end
    end

    context 'when namespace is present' do
      let(:group) { create(:group) }
      let(:workflow) { create(:duo_workflows_workflow, namespace: group) }

      it { is_expected.to be(false) }

      context 'when duo_workflow_mcp_enabled is enabled on root ancestor' do
        let(:group) { create(:group, ai_settings: ai_settings) }

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#archived?' do
    subject { workflow.archived? }

    context 'when created more than CHECKPOINT_RETENTION_DAYS ago' do
      let(:workflow) do
        build(:duo_workflows_workflow, created_at: (Ai::DuoWorkflows::CHECKPOINT_RETENTION_DAYS + 1).days.ago)
      end

      it { is_expected.to be(true) }
    end

    context 'when created exactly CHECKPOINT_RETENTION_DAYS ago' do
      let(:workflow) do
        build(:duo_workflows_workflow, created_at: Ai::DuoWorkflows::CHECKPOINT_RETENTION_DAYS.days.ago)
      end

      it { is_expected.to be(true) }
    end

    context 'when created less than CHECKPOINT_RETENTION_DAYS ago' do
      let(:workflow) do
        build(:duo_workflows_workflow, created_at: (Ai::DuoWorkflows::CHECKPOINT_RETENTION_DAYS - 1).days.ago)
      end

      it { is_expected.to be(false) }
    end

    context 'when created recently' do
      let(:workflow) { build(:duo_workflows_workflow, created_at: 1.day.ago) }

      it { is_expected.to be(false) }
    end
  end

  describe '#stalled?' do
    subject { workflow.stalled? }

    context 'when status is created and has no checkpoints' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it { is_expected.to be(false) }
    end

    context 'when status is not created and has no checkpoints' do
      let(:workflow) { create(:duo_workflows_workflow) }

      before do
        workflow.start! # transitions to :running
      end

      it { is_expected.to be(true) }
    end

    context 'when status is not created and has checkpoints' do
      let(:workflow) { create(:duo_workflows_workflow) }

      before do
        workflow.start! # transitions to :running
        create(:duo_workflows_checkpoint, workflow: workflow)
      end

      it { is_expected.to be(false) }
    end

    context 'when status is finished and has no checkpoints' do
      let(:workflow) { create(:duo_workflows_workflow) }

      before do
        workflow.start! # transitions to :running
        workflow.finish! # transitions to :finished
      end

      it { is_expected.to be(true) }
    end

    context 'when status is failed and has checkpoints' do
      let(:workflow) { create(:duo_workflows_workflow) }

      before do
        workflow.drop! # transitions to :failed
        create(:duo_workflows_checkpoint, workflow: workflow)
      end

      it { is_expected.to be(false) }
    end
  end
end
