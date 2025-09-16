# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::ProjectIndexIntegrityWorker, feature_category: :global_search do
  let_it_be(:project) { create(:project, :repository) }

  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when and project_id is not provided' do
      it 'does nothing' do
        expect(::Search::IndexRepairService).not_to receive(:execute)

        worker.perform(nil)
      end
    end

    context 'when project_id is provided' do
      it_behaves_like 'an idempotent worker' do
        let(:job_args) { [project.id] }

        it 'executes the index repair service for the project' do
          expect(::Search::IndexRepairService).to receive(:execute).with(project, params: {}).and_call_original

          worker.perform(project.id)
        end
      end

      context 'when project is not found' do
        it 'does nothing' do
          expect(::Search::IndexRepairService).not_to receive(:execute)

          worker.perform(non_existing_record_id)
        end
      end
    end
  end
end
