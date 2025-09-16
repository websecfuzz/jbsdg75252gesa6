# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::BuildFinishedWorker, feature_category: :continuous_integration do
  let_it_be(:ci_runner) { create(:ci_runner) }
  let_it_be_with_reload(:build) do
    create(:ee_ci_build, :sast, :success, runner: ci_runner, finished_at: 1.hour.ago)
  end

  let_it_be(:project) { build.project }
  let_it_be(:namespace) { project.shared_runners_limit_namespace }

  def namespace_stats
    namespace.namespace_statistics || namespace.create_namespace_statistics
  end

  def project_stats
    project.statistics || project.create_statistics(namespace: project.namespace)
  end

  describe '#perform' do
    subject(:perform) do
      described_class.new.perform(build.id)
    end

    context 'when on .com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
        allow_any_instance_of(EE::Project).to receive(:shared_runners_minutes_limit_enabled?).and_return(true) # rubocop:disable RSpec/AnyInstanceOf
      end

      it 'tracks secure scans' do
        expect(::Security::TrackSecureScansWorker).to receive(:perform_async)

        perform
      end

      context 'when exception is raised in `super`' do
        it 'does not enqueue the worker in EE' do
          allow(Ci::Build).to receive(:find_by_id).with(build.id).and_return(build)
          allow(build).to receive(:execute_hooks).and_raise(ArgumentError)

          expect { perform }.to raise_error(ArgumentError)

          expect(::Security::TrackSecureScansWorker).not_to receive(:perform_async)
        end
      end

      context 'when build does not have a security report' do
        let(:build) { create(:ee_ci_build, :success, runner: ci_runner) }

        it 'does not track secure scans' do
          expect(::Security::TrackSecureScansWorker).not_to receive(:perform_async)

          perform
        end
      end

      it 'does not track job on InstanceRunnerFailedJobs' do
        expect(Ci::InstanceRunnerFailedJobs).not_to receive(:track)

        perform
      end
    end

    context 'when not on .com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      it 'does not notify the owners of Groups' do
        expect(::Ci::Minutes::EmailNotificationService).not_to receive(:new)

        perform
      end

      it 'does not track secure scans' do
        expect(::Security::TrackSecureScansWorker).not_to receive(:perform_async)

        perform
      end

      it 'does not track job on InstanceRunnerFailedJobs' do
        expect(Ci::InstanceRunnerFailedJobs).not_to receive(:track)

        perform
      end
    end

    context 'when token revocation is disabled' do
      before do
        allow_next_instance_of(described_class) do |build_finished_worker|
          allow(build_finished_worker).to receive(:revoke_secret_detection_token?) { false }
        end
      end

      it 'does not scan security reports for token revocation' do
        expect(ScanSecurityReportSecretsWorker).not_to receive(:perform_async)

        perform
      end
    end

    it 'does not schedule processing of requirement reports by default' do
      expect(RequirementsManagement::ProcessRequirementsReportsWorker).not_to receive(:perform_async)

      perform
    end

    context 'with requirements' do
      let_it_be(:requirement) { create(:work_item, :requirement, project: project) }
      let_it_be(:user) { create(:user, reporter_of: project) }

      before do
        build.update!(user: user)
      end

      shared_examples 'does not schedule processing of requirement reports' do
        it do
          expect(RequirementsManagement::ProcessRequirementsReportsWorker).not_to receive(:perform_async)

          perform
        end
      end

      context 'when requirements feature is available' do
        before do
          stub_licensed_features(requirements: true)
        end

        it 'schedules processing of requirement reports' do
          expect(RequirementsManagement::ProcessRequirementsReportsWorker).to receive(:perform_async)

          perform
        end

        context 'when user has insufficient permissions to create test reports' do
          before do
            project.add_guest(user)
          end

          it_behaves_like 'does not schedule processing of requirement reports'
        end
      end

      context 'when requirements feature is not available' do
        before do
          stub_licensed_features(requirements: false)
        end

        it_behaves_like 'does not schedule processing of requirement reports'
      end
    end

    it 'does not save job on Ci::InstanceRunnerFailedJobs by default' do
      expect(Ci::InstanceRunnerFailedJobs).not_to receive(:track)

      perform
    end

    context 'when job failed', feature_category: :fleet_visibility do
      let(:build) { create(:ee_ci_build, :sast, :failed, runner: ci_runner) }

      it 'tracks job on InstanceRunnerFailedJobs' do
        expect(Ci::InstanceRunnerFailedJobs).to receive(:track).once

        perform
      end
    end

    it 'saves job on Ci::FinishedBuildChSyncEvent by default' do
      expect { perform }.to change { Ci::FinishedBuildChSyncEvent.all }
        .from([])
        .to([an_object_having_attributes(
          build_id: build.id, build_finished_at: build.finished_at, project_id: build.project.id)])
    end

    it 'ignores duplicate calls for same build' do
      described_class.new.perform(build.id)
      Ci::FinishedBuildChSyncEvent.pending.first.update!(processed: true)

      perform

      expect(Ci::FinishedBuildChSyncEvent.all).to contain_exactly(
        an_object_having_attributes(
          build_id: build.id, build_finished_at: build.finished_at, project_id: build.project.id, processed: true)
      )
    end

    context 'when build is not Ci::Build' do
      let(:build) do
        create(:ci_bridge, :success, finished_at: 1.hour.ago)
      end

      it 'does not save job on Ci::FinishedBuildChSyncEvent by default' do
        expect { perform }.not_to change { Ci::FinishedBuildChSyncEvent.count }
      end
    end
  end
end
