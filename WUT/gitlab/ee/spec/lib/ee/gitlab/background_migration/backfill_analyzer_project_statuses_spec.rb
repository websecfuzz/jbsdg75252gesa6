# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillAnalyzerProjectStatuses,
  feature_category: :security_asset_inventories do
  let(:migration_instance) do
    described_class.new(
      start_id: vulnerability_statistics_table.minimum(:project_id),
      end_id: vulnerability_statistics_table.maximum(:project_id),
      batch_table: :vulnerability_statistics,
      batch_column: :project_id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: SecApplicationRecord.connection
    )
  end

  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:projects_table) { table(:projects) }
  let(:pipelines_table) { partitioned_table(:p_ci_pipelines, database: :ci) }
  let(:builds_table) { partitioned_table(:p_ci_builds, database: :ci) }
  let(:builds_metadata_table) { table(:p_ci_builds_metadata, database: :ci) }
  let(:analyzer_project_statuses_table) { table(:analyzer_project_statuses, database: :sec) }
  let(:vulnerability_statistics_table) { table(:vulnerability_statistics, database: :sec) }

  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }
  let(:root_group) do
    namespaces_table.create!(name: 'root-group', path: 'root-group', type: 'Group', organization_id: organization.id)
  end

  let(:group) do
    namespaces_table.create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id)
  end

  let(:project_namespace) do
    namespaces_table.create!(name: 'project-namespace', path: 'project-namespace', type: 'Project',
      organization_id: organization.id)
  end

  let(:project) do
    projects_table.create!(
      id: 1,
      name: 'project',
      path: 'project',
      namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      organization_id: organization.id
    )
  end

  let(:pipeline) do
    pipelines_table.create!(
      project_id: project.id,
      status: 'success',
      partition_id: 100
    )
  end

  let(:analyzer_types) do
    {
      sast: 0,
      dast: 1,
      dependency_scanning: 2,
      container_scanning: 3,
      secret_detection: 4,
      sast_iac: 5,
      sast_advanced: 6
    }
  end

  let(:now) { Time.current }
  let(:partition_id) { 100 }

  before do
    root_group.update!(traversal_ids: [root_group.id])
    group.update!(traversal_ids: [root_group.id, group.id])

    vulnerability_statistic = create_vulnerability_statistic(project, traversal_ids: group.traversal_ids)
    vulnerability_statistic.update!(latest_pipeline_id: pipeline.id)
  end

  subject(:perform_migration) { migration_instance.perform }

  describe '#perform' do
    context 'with security analyzer builds' do
      let!(:cs_build) { create_build(project.id, pipeline.id, 'container_scanning', 'failed') }
      let!(:sd_build) { create_build(project.id, pipeline.id, 'secret_detection', 'success') }

      before do
        create_build(project.id, pipeline.id, 'sast', 'success')
        create_build(project.id, pipeline.id, 'dependency_scanning', 'failed', now)

        create_build(project.id, pipeline.id, 'sast', 'success', name: 'kics-iac-sast')
        create_build(project.id, pipeline.id, 'sast', 'failed', nil, name: 'gitlab-advanced-sast')
      end

      it 'creates analyzer project statuses for all analyzer types' do
        expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(0).to(6)
      end

      it 'correctly maps build statuses to analyzer statuses' do
        perform_migration

        expect_to_find_status(project.id, :dependency_scanning, :failed)
        expect_to_find_status(project.id, :container_scanning, :failed)
        expect_to_find_status(project.id, :secret_detection, :success)
      end

      it 'correctly handles and prioritize SAST analyzers' do
        perform_migration

        expect_to_find_status(project.id, :sast_iac, :success)
        expect_to_find_status(project.id, :sast, :failed)
        expect_to_find_status(project.id, :sast_advanced, :failed)
      end

      it 'sets traversal_ids correctly' do
        perform_migration

        statuses = analyzer_project_statuses_table.where(project_id: project.id)
        expect(statuses).to all(have_attributes(traversal_ids: group.traversal_ids))
      end

      it 'sets last_call based on build started_at' do
        perform_migration

        statuses = analyzer_project_statuses_table.where(project_id: project.id)
        expect(statuses.map(&:last_call)).to all(be_present)
        expect(find_status(project.id, :dependency_scanning)&.last_call.to_s).to eq(now.to_s)
      end

      it 'sets build_id for each analyzer status' do
        perform_migration

        statuses = analyzer_project_statuses_table.where(project_id: project.id)
        expect(statuses.map(&:build_id)).to all(be_present)

        expect(find_status(project.id, :container_scanning)&.build_id).to eq(cs_build.id)
        expect(find_status(project.id, :secret_detection)&.build_id).to eq(sd_build.id)
      end

      context 'when project is not archived' do
        it 'sets archived for each analyzer status' do
          perform_migration

          statuses = analyzer_project_statuses_table.where(project_id: project.id)
          expect(statuses.map(&:archived)).to all(be(false))
        end
      end

      context 'when project is archived' do
        before do
          vulnerability_statistics_table.all.update!(archived: true)
        end

        it 'sets archived for each analyzer status' do
          perform_migration

          statuses = analyzer_project_statuses_table.where(project_id: project.id)
          expect(statuses.map(&:archived)).to all(be(true))
        end
      end

      context 'with multiple projects' do
        let(:project_2_namespace) do
          namespaces_table.create!(name: 'project_2-namespace', path: 'project_2-namespace', type: 'Project',
            organization_id: organization.id)
        end

        let(:project_2) do
          projects_table.create!(
            id: 2,
            name: 'project-2',
            path: 'project-2',
            namespace_id: group.id,
            project_namespace_id: project_2_namespace.id,
            organization_id: organization.id
          )
        end

        let!(:pipeline_2) do
          pipelines_table.create!(
            project_id: project_2.id,
            status: 'success',
            partition_id: 100
          )
        end

        before do
          vulnerability_statistic = create_vulnerability_statistic(project_2, traversal_ids: group.traversal_ids)
          vulnerability_statistic.update!(latest_pipeline_id: pipeline_2.id)

          create_build(project_2.id, pipeline_2.id, :sast, 'success')
          create_build(project_2.id, pipeline_2.id, :dast, 'success')
        end

        it 'processes all projects in the batch' do
          expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(0).to(8)

          expect_to_find_status(project_2.id, :sast, :success)
          expect_to_find_status(project_2.id, :dast, :success)
        end
      end
    end

    context 'with a build containing multiple analyzer types' do
      let!(:multiple_analyzer_build) do
        create_build(project.id, pipeline.id, %w[sast dast dependency_scanning], 'success')
      end

      it 'creates a status entry for each analyzer type' do
        expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(0).to(3)
      end

      it 'correctly maps build statuses to analyzer statuses' do
        perform_migration

        expect_to_find_status(project.id, :sast, :success)
        expect_to_find_status(project.id, :dast, :success)
        expect_to_find_status(project.id, :dependency_scanning, :success)
      end

      it 'sets the same build_id for all analyzer types from the same build' do
        perform_migration

        statuses = [:sast, :dast, :dependency_scanning].map { |type| find_status(project.id, type) }
        expect(statuses.map(&:build_id)).to all(be_present)
        expect(statuses.map(&:build_id).uniq.size).to eq(1)
        expect(statuses.first.build_id).to eq(multiple_analyzer_build.id)
      end
    end

    context 'with existing analyzer statuses' do
      before do
        create_build(project.id, pipeline.id, 'sast', 'success')

        analyzer_project_statuses_table.create!(
          project_id: project.id,
          traversal_ids: group.traversal_ids,
          analyzer_type: analyzer_types[:sast],
          status: described_class::STATUS_ENUM[:not_configured],
          last_call: 3.days.ago,
          created_at: 2.days.ago,
          updated_at: 2.days.ago,
          build_id: 999
        )
      end

      it 'does not create new records' do
        expect { perform_migration }.not_to change { analyzer_project_statuses_table.count }
      end

      it 'does not modify existing record' do
        expect { perform_migration }.not_to change {
          status = find_status(project.id, :sast)
          [status.last_call, status.updated_at, status.build_id]
        }
      end
    end

    context 'when project has no pipeline' do
      before do
        vulnerability_statistics_table.find_by(project_id: project.id).update!(latest_pipeline_id: nil)
      end

      it 'skips the project' do
        expect { perform_migration }.not_to change { analyzer_project_statuses_table.count }
      end
    end

    context 'when pipeline has no builds' do
      it 'creates no analyzer project statuses' do
        expect { perform_migration }.not_to change { analyzer_project_statuses_table.count }
      end
    end

    context 'when a build has no security reports' do
      before do
        create_build(project.id, pipeline.id, nil, 'success')
      end

      it 'creates no analyzer project statuses' do
        expect { perform_migration }.not_to change { analyzer_project_statuses_table.count }
      end
    end
  end

  def create_build(project_id, pipeline_id, analyzer_types, status, started_at = Time.current, name: nil)
    analyzer_types = Array(analyzer_types).compact

    build = builds_table.create!(
      partition_id: partition_id,
      commit_id: pipeline_id,
      project_id: project_id,
      status: status,
      name: name || (analyzer_types.first ? "#{analyzer_types.first}_job" : "regular_job"),
      started_at: started_at
    )

    config_options = {}

    if analyzer_types.any?
      reports = {}
      analyzer_types.each { |type| reports[type] = {} }

      config_options = {
        'artifacts' => {
          'reports' => reports
        }
      }
    end

    builds_metadata_table.create!(
      build_id: build.id,
      project_id: project_id,
      partition_id: partition_id,
      config_options: config_options
    )

    build
  end

  def create_vulnerability_statistic(project, traversal_ids:)
    vulnerability_statistics_table.create!(
      project_id: project.id,
      traversal_ids: traversal_ids,
      total: 0,
      critical: 0,
      high: 0,
      medium: 0,
      low: 0,
      unknown: 0,
      info: 0,
      letter_grade: 0,
      created_at: Time.current,
      updated_at: Time.current
    )
  end

  def find_status(project_id, analyzer_type)
    analyzer_project_statuses_table.find_by(project_id: project_id,
      analyzer_type: ::Enums::Security.analyzer_types[analyzer_type])
  end

  def expect_to_find_status(project_id, analyzer_type, status)
    expect(find_status(project_id, analyzer_type)).to have_attributes(status: described_class::STATUS_ENUM[status])
  end
end
