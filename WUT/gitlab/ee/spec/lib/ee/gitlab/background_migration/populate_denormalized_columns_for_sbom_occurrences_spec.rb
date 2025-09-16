# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::PopulateDenormalizedColumnsForSbomOccurrences, schema: 20240116205430, feature_category: :dependency_management do
  before(:all) do
    # This migration will not work if a sec database is configured. It should be finalized and removed prior to
    # sec db rollout.
    # Consult https://gitlab.com/gitlab-org/gitlab/-/merge_requests/171707 for more info.
    skip_if_multiple_databases_are_setup(:sec)
  end

  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:users) { table(:users) }
  let(:sbom_components) { table(:sbom_components) }
  let(:sbom_sources) { table(:sbom_sources) }
  let(:sbom_occurrences) { table(:sbom_occurrences) }

  let(:organization) { organizations.create!(name: 'organization', path: 'organization') }
  let(:namespace) { namespaces.create!(name: 'Test Namespace', path: 'np-path-1', organization_id: organization.id) }
  let(:project) do
    projects.create!(
      name: 'Test',
      namespace_id: namespace.id,
      project_namespace_id: namespace.id,
      organization_id: organization.id
    )
  end

  let(:component_1) { sbom_components.create!(component_type: 0, name: 'Component 1') }
  let(:component_2) { sbom_components.create!(component_type: 0, name: 'Component 2') }
  let(:component_3) { sbom_components.create!(component_type: 0, name: 'Component 3') }
  let(:source_1) do
    sbom_sources.create!(
      source_type: 0,
      source: { package_manager: { name: 'bundler' }, input_file: { path: 'Gemfile.lock' } })
  end

  let(:source_2) do
    sbom_sources.create!(
      source_type: 0,
      source: { package_manager: { name: 'yarn' }, input_file: { path: 'yarn.lock' } })
  end

  let!(:occurrence_1) do
    sbom_occurrences.create!(
      component_id: component_1.id,
      source_id: source_1.id,
      project_id: project.id,
      uuid: SecureRandom.uuid,
      commit_sha: '')
  end

  let!(:occurrence_2) do
    sbom_occurrences.create!(
      component_id: component_2.id,
      source_id: source_2.id,
      project_id: project.id,
      uuid: SecureRandom.uuid,
      commit_sha: '')
  end

  let!(:occurrence_3) do
    sbom_occurrences.create!(
      component_id: component_3.id,
      project_id: project.id,
      uuid: SecureRandom.uuid,
      commit_sha: '')
  end

  let(:migration_instance) do
    described_class.new(
      start_id: sbom_occurrences.minimum(:id),
      end_id: sbom_occurrences.maximum(:id),
      batch_table: :sbom_occurrences,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: sbom_occurrences.connection
    )
  end

  subject(:perform_migration) { migration_instance.perform }

  it 'sets the denormalized columns' do
    expect do
      perform_migration

      occurrence_1.reload
      occurrence_2.reload
      occurrence_3.reload
    end.to change { occurrence_1.component_name }.from(nil).to('Component 1')
       .and change { occurrence_1.package_manager }.from(nil).to('bundler')
       .and change { occurrence_1.input_file_path }.from(nil).to('Gemfile.lock')
       .and change { occurrence_2.component_name }.from(nil).to('Component 2')
       .and change { occurrence_2.package_manager }.from(nil).to('yarn')
       .and change { occurrence_2.input_file_path }.from(nil).to('yarn.lock')
       .and change { occurrence_3.component_name }.from(nil).to('Component 3')
       .and not_change { occurrence_3.package_manager }.from(nil)
       .and not_change { occurrence_3.input_file_path }.from(nil)
  end
end
