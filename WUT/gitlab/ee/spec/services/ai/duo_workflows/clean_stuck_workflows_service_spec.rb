# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CleanStuckWorkflowsService, feature_category: :duo_workflow do
  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    where(:updated_when, :current_status, :expected_status) do
      "recent" | :created                      | :created
      "recent" | :running                      | :running
      "recent" | :paused                       | :paused
      "recent" | :finished                     | :finished
      "recent" | :failed                       | :failed
      "recent" | :stopped                      | :stopped
      "recent" | :input_required               | :input_required
      "recent" | :plan_approval_required       | :plan_approval_required
      "recent" | :tool_call_approval_required  | :tool_call_approval_required
      "old"    | :created                      | :failed
      "old"    | :running                      | :failed
      "old"    | :paused                       | :paused
      "old"    | :finished                     | :finished
      "old"    | :failed                       | :failed
      "old"    | :stopped                      | :stopped
      "old"    | :input_required               | :input_required
      "old"    | :plan_approval_required       | :plan_approval_required
      "old"    | :tool_call_approval_required  | :tool_call_approval_required
    end

    with_them do
      action = params[:current_status] == params[:expected_status] ? "keeps" : "changes"
      test_case_name = "#{action} #{params[:updated_when]} workflow status: " \
        "#{params[:current_status]} → #{params[:expected_status]}"
      it test_case_name do
        updated_at = updated_when == "old" ? 2.days.ago : 1.minute.ago
        workflow = create(:duo_workflows_workflow, status: status_enum(current_status), updated_at: updated_at)
        expect(workflow.reload.status).to eq(status_enum(current_status))
        described_class.new.execute
        expect(workflow.reload.status).to eq(status_enum(expected_status))
      end
    end
  end

  def status_enum(status)
    Ai::DuoWorkflows::Workflow.state_machine.states[status].value
  end
end
