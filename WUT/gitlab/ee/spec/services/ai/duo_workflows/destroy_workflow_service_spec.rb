# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::DestroyWorkflowService, feature_category: :duo_workflow do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, maintainer_of: project) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }

    subject(:execute) do
      described_class
        .new(workflow: workflow, current_user: user)
        .execute
    end

    it 'destroys a workflow' do
      expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(-1)
    end

    context 'when user can not destroy workflow' do
      let_it_be(:other_user) { create(:user) }

      subject(:execute) do
        described_class
          .new(workflow: workflow, current_user: other_user)
          .execute
      end

      it 'returns an error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:message]).to include('User not authorized to delete workflow')
      end
    end

    context 'when the workflow cannot be destroyed' do
      before do
        allow(workflow).to receive(:destroy).and_return(false)
        workflow.errors.add(:base, "Something bad")
      end

      it 'returns an error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:message]).to include('Something bad')
      end
    end
  end
end
