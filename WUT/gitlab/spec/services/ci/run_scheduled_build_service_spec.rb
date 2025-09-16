# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunScheduledBuildService, :aggregate_failures, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project, created_at: 1.day.ago) }

  subject(:execute_service) { described_class.new(build).execute }

  context 'when user can update build' do
    before_all do
      project.add_developer(user)
    end

    before do
      create(:protected_branch, :developers_can_merge, name: pipeline.ref, project: project)
    end

    context 'when build is scheduled' do
      context 'when scheduled_at is expired' do
        let(:build) { create(:ci_build, :expired_scheduled, user: user, project: project, pipeline: pipeline) }

        it 'can run the build' do
          expect { execute_service }.not_to raise_error

          expect(build).to be_pending
        end

        context 'when build requires resource' do
          let(:resource_group) { create(:ci_resource_group, project: project) }

          before do
            build.update!(resource_group: resource_group)
          end

          it 'transits to waiting for resource status' do
            expect { execute_service }.to change { build.status }.from('scheduled').to('waiting_for_resource')
          end
        end
      end

      context 'when scheduled_at is not expired' do
        let(:build) { create(:ci_build, :scheduled, user: user, project: project, pipeline: pipeline) }

        it 'can not run the build' do
          expect { execute_service }.to raise_error(StateMachines::InvalidTransition)

          expect(build).to be_scheduled
        end
      end
    end

    context 'when build is not scheduled' do
      let(:build) { create(:ci_build, :created, user: user, project: project, pipeline: pipeline) }

      it 'can not run the build' do
        expect { execute_service }.to raise_error(StateMachines::InvalidTransition)

        expect(build).to be_created
      end
    end

    context 'when the pipeline is archived' do
      let(:build) { create(:ci_build, :scheduled, user: user, project: project, pipeline: pipeline) }

      before do
        stub_application_setting(archive_builds_in_seconds: 3600)
      end

      it 'can not run the build' do
        expect { execute_service }.to raise_error(Gitlab::Access::AccessDeniedError)

        expect(build).to be_scheduled
      end
    end
  end

  context 'when user can not update build' do
    context 'when build is scheduled' do
      let(:build) { create(:ci_build, :scheduled, user: user, project: project, pipeline: pipeline) }

      it 'can not run the build' do
        expect { execute_service }.to raise_error(Gitlab::Access::AccessDeniedError)

        expect(build).to be_scheduled
      end
    end
  end
end
