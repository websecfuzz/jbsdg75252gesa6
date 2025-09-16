# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ml::CreateExperimentService, feature_category: :mlops do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { project.first_owner }
  let_it_be(:existing_experiment) { create(:ml_experiments, project: project, user: user) }

  let(:name) { 'new_experiment' }

  subject(:create_experiment) { described_class.new(project, name, user).execute }

  describe '#execute' do
    subject(:created_experiment) { create_experiment.payload }

    it 'creates an experiment', :aggregate_failures do
      expect(create_experiment).to be_success
      expect(created_experiment.name).to eq('new_experiment')
      expect(created_experiment.project).to eq(project)
      expect(created_experiment.user).to eq(user)
    end

    context 'when experiment already exists' do
      let(:name) { existing_experiment.name }

      it 'returns an error', :aggregate_failures do
        expect { create_experiment }.not_to change { Ml::Experiment.count }

        expect(create_experiment).to be_error
      end
    end

    context 'with invalid parameters' do
      let(:name) { '' }

      it 'returns validation errors' do
        response = create_experiment

        expect(response).to be_error
        expect(response.message).to include("Name can't be blank")
      end
    end

    context 'when a RecordNotUnique error occurs' do
      let_it_be(:pg_error) { 'PG::UniqueViolation: ERROR: duplicate key value violates unique constraint' }

      before do
        allow_next_instance_of(::Ml::Experiment) do |experiment|
          allow(experiment).to receive(:save).and_raise(
            ActiveRecord::RecordNotUnique.new(pg_error)
          )
        end
      end

      it 'returns an error response with the exception message' do
        response = create_experiment

        expect(response).to be_error
        expect(response.message).to include(pg_error)
      end

      it 'does not persist the experiment' do
        expect { create_experiment }.not_to change { Ml::Experiment.count }
      end
    end
  end
end
