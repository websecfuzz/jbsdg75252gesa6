# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowPolicy, feature_category: :duo_workflow do
  using RSpec::Parameterized::TableSyntax

  subject(:policy) { described_class.new(current_user, workflow) }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }
  let_it_be(:guest) { create(:user, guest_of: workflow.project) }
  let_it_be(:developer) { create(:user, developer_of: workflow.project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: workflow.project) }

  let(:current_user) { developer }

  describe "read_duo_workflow and update_duo_workflow" do
    where(:duo_features_enabled, :current_user, :stage_check_available, :user_is_allowed_to_use, :allowed) do
      true   | ref(:developer)  | true  | false | false
      true   | ref(:developer)  | false | false | false
      true   | ref(:maintainer) | false | false | false
      true   | ref(:maintainer) | true  | false | false
      true   | ref(:guest)      | true  | false | false
      false  | ref(:developer)  | true  | false | false
      true   | ref(:maintainer) | true  | true  | true
      true   | ref(:guest)      | true  | true  | false
      true   | ref(:developer)  | true  | true  | true
    end

    with_them do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project,
          :duo_workflow).and_return(stage_check_available)
        allow(current_user).to receive(:allowed_to_use?).and_return(user_is_allowed_to_use)
        project.project_setting.update!(duo_features_enabled: duo_features_enabled)
        workflow.update!(user: current_user)
      end

      it 'checks read and update workflow policy' do
        is_expected.to(allowed ? be_allowed(:read_duo_workflow) : be_disallowed(:read_duo_workflow))
        is_expected.to(allowed ? be_allowed(:update_duo_workflow) : be_disallowed(:update_duo_workflow))
      end
    end

    context "when user is not workflow owner" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        project.project_setting.update!(duo_features_enabled: true)
        workflow.update!(user: maintainer)
      end

      it { is_expected.to be_disallowed(:read_duo_workflow) }
      it { is_expected.to be_disallowed(:update_duo_workflow) }

      context "when current user is a service account" do
        let(:current_user) do
          create(:user, :service_account, developer_of: workflow.project, composite_identity_enforced: true)
        end

        before do
          allow(current_user).to receive(:allowed_to_use?).and_return(true)
        end

        it { is_expected.to be_allowed(:read_duo_workflow) }
        it { is_expected.to be_allowed(:update_duo_workflow) }
      end
    end

    context "when feature flag is disabled" do
      before do
        stub_feature_flags(duo_workflow: false)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        project.project_setting.update!(duo_features_enabled: true)
        workflow.update!(user: current_user)
      end

      it { is_expected.to be_disallowed(:read_duo_workflow) }
      it { is_expected.to be_disallowed(:update_duo_workflow) }
    end
  end

  describe "read_duo_workflow and update_duo_workflow for project-level agentic chat" do
    let_it_be(:workflow) { create(:duo_workflows_workflow, :agentic_chat, project: project) }

    before do
      allow(policy).to receive(:can?).with(:access_duo_agentic_chat, project)
        .and_return(can_use_agentic_chat)
    end

    context "when agentic chat is allowed" do
      let(:can_use_agentic_chat) { true }

      context "when current user is workflow owner" do
        before do
          workflow.update!(user: current_user)
        end

        it 'allows read and update workflow policy' do
          is_expected.to be_allowed(:read_duo_workflow)
          is_expected.to be_allowed(:update_duo_workflow)
        end
      end

      context "when current user is not workflow owner" do
        before do
          workflow.update!(user: create(:user))
        end

        it 'disallows read and update workflow policy' do
          is_expected.to be_disallowed(:read_duo_workflow)
          is_expected.to be_disallowed(:update_duo_workflow)
        end
      end
    end

    context "when agentic chat is disallowed" do
      let(:can_use_agentic_chat) { false }

      before do
        workflow.update!(user: current_user)
      end

      it 'disallows read and update workflow policy' do
        is_expected.to be_disallowed(:read_duo_workflow)
        is_expected.to be_disallowed(:update_duo_workflow)
      end
    end
  end

  describe "read_duo_workflow and update_duo_workflow for namespace-level agentic chat" do
    let_it_be(:workflow) { create(:duo_workflows_workflow, :agentic_chat, namespace: group) }

    before do
      allow(policy).to receive(:can?).with(:access_duo_agentic_chat, group)
        .and_return(can_use_agentic_chat)
    end

    context "when agentic chat is allowed" do
      let(:can_use_agentic_chat) { true }

      context "when current user is workflow owner" do
        before do
          workflow.update!(user: current_user)
        end

        it 'allows read and update workflow policy' do
          is_expected.to be_allowed(:read_duo_workflow)
          is_expected.to be_allowed(:update_duo_workflow)
        end
      end

      context "when current user is not workflow owner" do
        before do
          workflow.update!(user: create(:user))
        end

        it 'disallows read and update workflow policy' do
          is_expected.to be_disallowed(:read_duo_workflow)
          is_expected.to be_disallowed(:update_duo_workflow)
        end
      end
    end

    context "when agentic chat is disallowed" do
      let(:can_use_agentic_chat) { false }

      before do
        workflow.update!(user: current_user)
      end

      it 'disallows read and update workflow policy' do
        is_expected.to be_disallowed(:read_duo_workflow)
        is_expected.to be_disallowed(:update_duo_workflow)
      end
    end
  end

  describe "execute_duo_workflow_in_ci" do
    where(:duo_workflow_ff, :duo_workflow_in_ci_ff, :duo_features_enabled, :current_user, :stage_check, :allowed) do
      false | false | true   | ref(:developer)  | true  | false
      true  | false | true   | ref(:developer)  | true  | false
      false | true  | true   | ref(:developer)  | true  | false
      true  | true  | true   | ref(:maintainer) | false | false
      true  | true  | true   | ref(:developer)  | true  | true
      true  | true  | true   | ref(:guest)      | true  | false
      true  | true  | false  | ref(:developer)  | true  | false
    end

    with_them do
      before do
        stub_feature_flags(duo_workflow: duo_workflow_ff, duo_workflow_in_ci: duo_workflow_in_ci_ff)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(stage_check)
        allow(current_user).to receive(:allowed_to_use?).and_return(true)
        project.project_setting.update!(duo_features_enabled: duo_features_enabled)
        workflow.update!(user: current_user)
      end

      it 'checks execute_duo_workflow_in_ci policy' do
        is_expected.to(allowed ? be_allowed(:execute_duo_workflow_in_ci) : be_disallowed(:execute_duo_workflow_in_ci))
      end
    end
  end

  describe 'destroy_duo_workflow' do
    context 'when user owns the thread' do
      let(:current_user) { workflow.user }

      it { is_expected.to be_allowed(:destroy_duo_workflow) }
    end

    context 'when user does not own the thread' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_disallowed(:destroy_duo_workflow) }
    end
  end
end
