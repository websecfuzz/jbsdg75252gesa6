# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::UpdateService, feature_category: :vulnerability_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:pipeline) { create(:ci_empty_pipeline, project: project) }
  let_it_be(:traversal_ids) { group.traversal_ids }

  let(:service) { described_class.new(pipeline) }
  let(:diff_service) { instance_double(Security::AnalyzersStatus::DiffService) }
  let(:ancestors_update_service) { class_double(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService) }
  let(:status_diff) do
    {
      namespace_id: group.id,
      traversal_ids: group.traversal_ids,
      diff: { sast: { 'success' => 1 }, dast: { 'failed' => 1 } }
    }
  end

  before do
    allow(Security::AnalyzersStatus::DiffService).to receive(:new).and_return(diff_service)
    allow(diff_service).to receive(:execute).and_return(status_diff)

    stub_const('Security::AnalyzerNamespaceStatuses::AncestorsUpdateService', ancestors_update_service)
    allow(ancestors_update_service).to receive(:execute)
  end

  shared_examples 'calls namespace related services' do
    it 'calls DiffService and passes diffs to NamespaceUpdateService' do
      execute

      expect(Security::AnalyzersStatus::DiffService).to have_received(:new).with(
        project,
        kind_of(Hash)
      )
      expect(diff_service).to have_received(:execute)
      expect(ancestors_update_service).to have_received(:execute).with(status_diff)
    end
  end

  shared_examples 'creates aggregated status from pipeline-based status' do |analyzer_type, pipeline_type, status|
    it "creates #{analyzer_type} aggregated status as #{status} from #{pipeline_type}" do
      expect { execute }.to change {
        Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: analyzer_type)&.status
      }.from(nil).to(status.to_s)
    end
  end

  shared_examples 'updates aggregated status from pipeline-based status' do
    |analyzer_type, pipeline_type, old_status, new_status|
    it "updates #{analyzer_type} aggregated status from #{old_status} to #{new_status}" do
      create(:analyzer_project_status, project: project, analyzer_type: analyzer_type, status: old_status)
      create(:analyzer_project_status, project: project, analyzer_type: pipeline_type, status: old_status)

      expect { execute }.to change {
        Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: analyzer_type).status
      }.from(old_status.to_s).to(new_status.to_s)
    end
  end

  shared_examples 'preserves higher priority aggregated status' do |analyzer_type, expected_status|
    it "keeps #{analyzer_type} as #{expected_status}" do
      create(:analyzer_project_status, project: project, analyzer_type: analyzer_type, status: expected_status)

      expect { execute }.not_to change {
        Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: analyzer_type).status
      }
    end
  end

  shared_examples 'updates aggregated status based on priority' do
    |analyzer_type, pipeline_type, pipeline_status, expected_status|
    it "updates #{analyzer_type} to #{expected_status} when pipeline #{pipeline_type} is #{pipeline_status}" do
      create(:analyzer_project_status, project: project, analyzer_type: analyzer_type, status: :not_configured)
      create(:analyzer_project_status, project: project, analyzer_type: pipeline_type, status: pipeline_status)

      expect { execute }.to change {
        Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: analyzer_type).status
      }.from('not_configured').to(expected_status.to_s)
    end
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when pipeline doesnt exist' do
      let(:service) { described_class.new(nil) }

      it 'returns nil without processing' do
        expect(execute).to be_nil
      end
    end

    context 'when project doesnt exist' do
      before do
        allow(pipeline).to receive(:project).and_return(nil)
      end

      it 'returns nil without processing' do
        expect(execute).to be_nil
      end
    end

    context 'when post_pipeline_analyzer_status_updates feature flag is disabled' do
      before do
        stub_feature_flags(post_pipeline_analyzer_status_updates: false)
      end

      it 'returns nil without processing' do
        expect(execute).to be_nil
      end
    end

    context 'when post_pipeline_analyzer_status_updates feature flag is enabled' do
      context 'when pipeline and project are present' do
        context 'with various security jobs' do
          let!(:sast_build) { create(:ci_build, :sast, :success, pipeline: pipeline, started_at: nil) }
          let!(:dependency_scanning_build) { create(:ci_build, :dependency_scanning, :canceled, pipeline: pipeline) }
          let!(:container_scanning_build) { create(:ci_build, :container_scanning, :skipped, pipeline: pipeline) }
          let!(:secret_detection_build) { create(:ci_build, :secret_detection, :success, pipeline: pipeline) }

          let!(:kics_build) do
            build = create(:ci_build, :success, pipeline: pipeline, name: 'kics-iac-sast')
            setup_build_reports(build, [:sast])
            build
          end

          let!(:advanced_sast_build) do
            build = create(:ci_build, :success, pipeline: pipeline, name: 'gitlab-advanced-sast')
            setup_build_reports(build, [:sast])
            build
          end

          it 'creates new records for analyzers in the pipeline with their aggregated types' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.from(0).to(8)

            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast))
              .to have_attributes(status: 'success', build_id: sast_build.id)

            expect(Security::AnalyzerProjectStatus
              .find_by(project: project, analyzer_type: :container_scanning_pipeline_based))
              .to have_attributes(status: 'failed', build_id: container_scanning_build.id)

            # aggregated status
            expect(Security::AnalyzerProjectStatus
              .find_by(project: project, analyzer_type: :container_scanning))
              .to have_attributes(status: 'failed')

            expect(Security::AnalyzerProjectStatus
              .find_by(project: project, analyzer_type: :secret_detection_pipeline_based))
              .to have_attributes(status: 'success', build_id: secret_detection_build.id)

            # aggregated status
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :secret_detection))
              .to have_attributes(status: 'success')

            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast_iac))
              .to have_attributes(status: 'success', build_id: kics_build.id)

            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast_advanced))
              .to have_attributes(status: 'success', build_id: advanced_sast_build.id)

            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :dependency_scanning))
              .to have_attributes(status: 'failed', build_id: dependency_scanning_build.id)
          end

          it 'updates existing records for analyzers in the pipeline' do
            sast_status = create(:analyzer_project_status, project: project, analyzer_type: :sast,
              status: :not_configured)
            ds_status = create(:analyzer_project_status, project: project, analyzer_type: :dependency_scanning,
              status: :success)

            expect { execute }.to change { sast_status.reload.status }.from('not_configured').to('success')
              .and change { ds_status.reload.status }.from('success').to('failed')
          end

          it 'updates existing records not in the pipeline to not_configured' do
            existing_dast_status = create(:analyzer_project_status, project: project, analyzer_type: :dast,
              status: :success)

            expect { execute }.to change { existing_dast_status.reload.status }.from('success').to('not_configured')
          end

          it 'doesnt update existing setting based records to not_configured' do
            existing_spp_status = create(:analyzer_project_status, project: project,
              analyzer_type: :secret_detection_secret_push_protection, status: :success)

            expect { execute }.not_to change { existing_spp_status.reload.status }
          end

          it 'updates the archive column' do
            archived_status = create(:analyzer_project_status, project: project, analyzer_type: :sast,
              status: :success, archived: true)

            expect { execute }.to change { archived_status.reload.archived }.from(true).to(false)
          end

          it 'updates the last_call column' do
            sast_status = create(:analyzer_project_status, project: project, analyzer_type: :sast,
              status: :not_configured)
            ds_status = create(:analyzer_project_status, project: project, analyzer_type: :dependency_scanning,
              status: :success)

            # prefer started_at with fallback to created_at
            expect { execute }.to change { sast_status.reload.last_call }.to(sast_build.created_at)
              .and change { ds_status.reload.last_call }.to(dependency_scanning_build.started_at)
          end

          it 'updates the updated_at column' do
            old_status = create(:analyzer_project_status, project: project, analyzer_type: :cluster_image_scanning,
              status: :failed, updated_at: 1.week.ago)

            expect { execute }.to change { old_status.reload.updated_at }
          end

          include_examples 'calls namespace related services'
        end

        context 'with multiple jobs of the same analyzer group type' do
          let!(:sast_build_1) { create(:ci_build, :sast, :success, pipeline: pipeline) }
          let!(:sast_build_2) { create(:ci_build, :sast, :failed, pipeline: pipeline) }
          let!(:advanced_sast_build) do
            build = create(:ci_build, :failed, pipeline: pipeline, name: 'gitlab-advanced-sast')
            setup_build_reports(build, [:sast])
            build
          end

          it 'prioritize failed jobs' do
            expect { execute }.to change { Security::AnalyzerProjectStatus.count }.from(0).to(2)
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast).status)
              .to eq('failed')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast_advanced).status)
              .to eq('failed')
          end

          include_examples 'calls namespace related services'
        end

        context 'with a build that has multiple security report types' do
          let!(:multi_report_build) do
            build = create(:ci_build, :success, pipeline: pipeline, name: 'multi-scanner')
            # Setup multiple report types for the build
            setup_build_reports(build, [:sast, :dast, :dependency_scanning])
            build
          end

          it 'processes all analyzer types from the single build' do
            execute

            expect(Security::AnalyzerProjectStatus.where(project: project).count).to eq(3)

            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :sast).status)
              .to eq('success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :dast).status)
              .to eq('success')
            expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :dependency_scanning)
              .status).to eq('success')
          end

          include_examples 'calls namespace related services'
        end

        context 'when no security jobs are found' do
          let!(:build) { create(:ci_build, :success, pipeline: pipeline) }

          it 'sets all pipeline analyzer statuses to not_configured' do
            sast_status = create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :success)
            dast_status = create(:analyzer_project_status, project: project, analyzer_type: :dast, status: :failed)

            expect { execute }.to change { sast_status.reload.status }.from('success').to('not_configured')
              .and change { dast_status.reload.status }.from('failed').to('not_configured')
          end

          it 'sets aggregated type statuses to not_configured' do
            sd_pipeline_status = create(:analyzer_project_status, project: project,
              analyzer_type: :secret_detection_pipeline_based, status: :success)
            sd_aggregated_status = create(:analyzer_project_status, project: project,
              analyzer_type: :secret_detection, status: :failed)

            expect { execute }.to change { sd_pipeline_status.reload.status }.from('success').to('not_configured')
              .and change { sd_aggregated_status.reload.status }.from('failed').to('not_configured')
          end

          it 'sets aggregated type statuses to not_configured when no previous record exists' do
            create(:analyzer_project_status, project: project,
              analyzer_type: :secret_detection_pipeline_based, status: :success)

            expect { execute }.to change {
              Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :secret_detection)&.status
            }.from(nil).to('not_configured')
          end

          include_examples 'calls namespace related services'
        end

        context 'when an exception occurs' do
          before do
            allow(service).to receive(:pipeline_builds).and_raise(StandardError.new("Test error"))
          end

          it 'tracks the exception with error tracking' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception)
              .with(an_instance_of(StandardError), hash_including(project_id: project.id, pipeline_id: pipeline.id))

            execute
          end

          it 'doesnt call NamespaceUpdateService' do
            execute

            expect(ancestors_update_service).not_to have_received(:execute)
          end
        end

        context 'with aggregated type handling' do
          context 'for secret_detection aggregated type' do
            let!(:secret_detection_build) { create(:ci_build, :secret_detection, :success, pipeline: pipeline) }

            context 'when only pipeline-based status exists' do
              include_examples 'creates aggregated status from pipeline-based status',
                :secret_detection, :secret_detection_pipeline_based, :success
            end

            context 'when aggregated status already exists' do
              include_examples 'updates aggregated status from pipeline-based status',
                :secret_detection, :secret_detection_pipeline_based, :not_configured, :success
            end

            context 'when both pipeline-based and setting-based statuses exist' do
              context 'when setting-based has higher priority' do
                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :secret_detection_secret_push_protection, status: :not_configured)
                end

                include_examples 'preserves higher priority aggregated status',
                  :secret_detection, :success
              end

              context 'when pipeline-based has higher priority (failed)' do
                let!(:secret_detection_build) { create(:ci_build, :secret_detection, :failed, pipeline: pipeline) }

                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :secret_detection_secret_push_protection, status: :success)
                end

                include_examples 'updates aggregated status based on priority',
                  :secret_detection, :secret_detection_pipeline_based, :failed, :failed
              end

              context 'when both have same priority (success)' do
                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :secret_detection_secret_push_protection, status: :success)
                end

                include_examples 'creates aggregated status from pipeline-based status',
                  :secret_detection, :secret_detection_pipeline_based, :success
              end

              context 'when setting-based is not_configured' do
                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :secret_detection_secret_push_protection, status: :not_configured)
                end

                include_examples 'creates aggregated status from pipeline-based status',
                  :secret_detection, :secret_detection_pipeline_based, :success
              end
            end
          end

          context 'for container_scanning aggregated type' do
            let!(:container_scanning_build) { create(:ci_build, :container_scanning, :failed, pipeline: pipeline) }

            context 'when only pipeline-based status exists' do
              include_examples 'creates aggregated status from pipeline-based status',
                :container_scanning, :container_scanning_pipeline_based, :failed
            end

            context 'when aggregated status already exists' do
              include_examples 'updates aggregated status from pipeline-based status',
                :container_scanning, :container_scanning_pipeline_based, :success, :failed
            end

            context 'when both pipeline-based and setting-based statuses exist' do
              context 'when setting-based has higher priority' do
                let!(:container_scanning_build) { create(:ci_build, :container_scanning, :success, pipeline: pipeline) }

                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :container_scanning_for_registry, status: :failed)
                end

                include_examples 'preserves higher priority aggregated status',
                  :container_scanning, :failed
              end

              context 'when pipeline-based has higher priority (failed)' do
                before do
                  create(:analyzer_project_status, project: project,
                    analyzer_type: :container_scanning_for_registry, status: :success)
                end

                include_examples 'updates aggregated status based on priority',
                  :container_scanning, :container_scanning_pipeline_based, :failed, :failed
              end
            end
          end

          context 'when aggregated status would not change' do
            let!(:secret_detection_build) { create(:ci_build, :secret_detection, :success, pipeline: pipeline) }
            let(:status) { Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :secret_detection) }

            it 'update aggregated status build and last_call when it already has the correct status' do
              create(:analyzer_project_status, project: project, analyzer_type: :secret_detection, status: :success)
              create(:analyzer_project_status, project: project,
                analyzer_type: :secret_detection_secret_push_protection, status: :not_configured)

              expect { execute }.to change { status.reload.last_call }
                .and change { status.reload.build_id }
                .and change { status.reload.updated_at }
            end
          end

          context 'when no aggregated types are configured in pipeline' do
            let!(:sast_build) { create(:ci_build, :sast, :success, pipeline: pipeline) }
            let!(:dast_build) { create(:ci_build, :dast, :failed, pipeline: pipeline) }

            it 'does not create aggregated status records for non-aggregated types' do
              execute

              expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :secret_detection))
                .to be_nil
              expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :container_scanning))
                .to be_nil
            end
          end

          context 'with multiple aggregated types' do
            let!(:secret_detection_build) { create(:ci_build, :secret_detection, :success, pipeline: pipeline) }
            let!(:container_scanning_build) { create(:ci_build, :container_scanning, :failed, pipeline: pipeline) }

            before do
              create(:analyzer_project_status, project: project,
                analyzer_type: :container_scanning_for_registry, status: :success)
              create(:analyzer_project_status, project: project,
                analyzer_type: :secret_detection_secret_push_protection, status: :not_configured)
              create(:analyzer_project_status, project: project,
                analyzer_type: :secret_detection, status: :not_configured)
            end

            it 'handles multiple aggregated types correctly' do
              execute

              expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :container_scanning))
               .to have_attributes(status: 'failed', build_id: container_scanning_build.id)

              expect(Security::AnalyzerProjectStatus.find_by(project: project, analyzer_type: :secret_detection))
                .to have_attributes(status: 'success', build_id: secret_detection_build.id)
            end
          end
        end
      end
    end
  end

  def setup_build_reports(build, report_types)
    options = build.options || {}
    options[:artifacts] ||= {}
    options[:artifacts][:reports] ||= {}

    report_types.each do |type|
      options[:artifacts][:reports][type] = {}
    end

    build.update!(options: options)
  end
end
