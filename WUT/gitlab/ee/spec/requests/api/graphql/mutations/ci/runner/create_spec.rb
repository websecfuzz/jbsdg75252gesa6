# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ci::Runner::Create, feature_category: :runner do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }

  let(:mutation) { graphql_mutation(:runner_create, mutation_params) }

  subject(:mutation_result) { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:runner_create)
  end

  context 'when user can create runner', :enable_admin_mode do
    let(:current_user) { create(:user, :admin) }

    context 'when create mutation includes cost factor arguments' do
      let(:public_cost_factor) { 2.5 }
      let(:private_cost_factor) { 0.5 }
      let(:mutation_params) do
        {
          runner_type: 'INSTANCE_TYPE',
          public_projects_minutes_cost_factor: public_cost_factor,
          private_projects_minutes_cost_factor: private_cost_factor
        }
      end

      it 'sets cost factors to specified values', :aggregate_failures do
        expect_next_instance_of(::Ci::Runners::CreateRunnerService) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        mutation_result

        expect_graphql_errors_to_be_empty
        expect(mutation_response).to have_key('runner')
        expect(mutation_response['runner']['publicProjectsMinutesCostFactor']).to eq(public_cost_factor)
        expect(mutation_response['runner']['privateProjectsMinutesCostFactor']).to eq(private_cost_factor)

        runner = GitlabSchema.object_from_id(mutation_response['runner']['id'], expected_type: ::Ci::Runner).sync
        expect(runner.public_projects_minutes_cost_factor).to eq(public_cost_factor)
        expect(runner.private_projects_minutes_cost_factor).to eq(private_cost_factor)
      end
    end
  end
end
