# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::FixProjectSettingsHasVulnerabilities, feature_category: :vulnerability_management do
  let(:users) { table(:users) }
  let(:scanners) { table(:vulnerability_scanners, database: :sec) }
  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:project_settings) { table(:project_settings) }

  let(:vulnerabilities) { table(:vulnerabilities, database: :sec) }
  let(:vulnerability_reads) { table(:vulnerability_reads, database: :sec) }
  let(:vulnerability_occurrences) { table(:vulnerability_occurrences, database: :sec) }
  let(:vulnerability_identifiers) { table(:vulnerability_identifiers, database: :sec) }

  let(:user) { users.create!(email: 'john@doe', username: 'john_doe', projects_limit: 10) }
  let(:organization) { organizations.create!(name: 'Organization', path: 'organization') }
  let(:namespace) { namespaces.create!(name: 'Test', path: 'test', organization_id: organization.id) }
  let(:project_namespace_1) { namespaces.create!(name: 'Project 1', path: 'proj_1', organization_id: organization.id) }
  let(:project_namespace_2) { namespaces.create!(name: 'Project 2', path: 'proj_2', organization_id: organization.id) }
  let(:project_namespace_3) { namespaces.create!(name: 'Project 3', path: 'proj_3', organization_id: organization.id) }

  let(:project_1) do
    projects.create!(
      name: 'project_1',
      path: 'project_1',
      namespace_id: namespace.id,
      project_namespace_id: project_namespace_1.id,
      organization_id: organization.id
    )
  end

  let(:project_2) do
    projects.create!(
      name: 'project_2',
      path: 'project_2',
      namespace_id: namespace.id,
      project_namespace_id: project_namespace_2.id,
      organization_id: organization.id
    )
  end

  let(:project_3) do
    projects.create!(
      name: 'project_3',
      path: 'project_3',
      namespace_id: namespace.id,
      project_namespace_id: project_namespace_3.id,
      organization_id: organization.id
    )
  end

  let!(:project_settings_1) { project_settings.create!(project_id: project_1.id, has_vulnerabilities: true) }
  let!(:project_settings_2) { project_settings.create!(project_id: project_2.id, has_vulnerabilities: false) }
  let!(:project_settings_3) { project_settings.create!(project_id: project_3.id, has_vulnerabilities: false) }

  let(:migration) do
    described_class.new(
      start_id: vulnerability_reads.minimum(:project_id),
      end_id: vulnerability_reads.maximum(:project_id),
      batch_table: :vulnerability_reads,
      batch_column: :project_id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: vulnerability_reads.connection
    )
  end

  before do
    create_vulnerability_read(project_1.id)
    create_vulnerability_read(project_2.id)
  end

  it 'updates project_settings#has_vulnerabilities for vulnerable projects' do
    expect { migration.perform }.to change { project_settings_2.reload.has_vulnerabilities }.to(true)
                                .and not_change { project_settings_1.reload.has_vulnerabilities }.from(true)
                                .and not_change { project_settings_3.reload.has_vulnerabilities }.from(false)
  end

  def create_vulnerability_read(project_id)
    scanner = scanners.create!(
      project_id: project_id,
      external_id: 'external-id',
      name: 'Scanner'
    )

    identifier = vulnerability_identifiers.create!(
      project_id: project_id,
      fingerprint: SecureRandom.bytes(20),
      external_type: '',
      external_id: '',
      name: ''
    )

    finding = vulnerability_occurrences.create!(
      project_id: project_id,
      severity: 1,
      report_type: 1,
      scanner_id: scanner.id,
      primary_identifier_id: identifier.id,
      location_fingerprint: '',
      name: 'name',
      metadata_version: '15.0',
      raw_metadata: '',
      uuid: SecureRandom.uuid
    )

    attrs = {
      project_id: project_id,
      author_id: user.id,
      title: 'title',
      severity: 1,
      report_type: 1,
      finding_id: finding.id
    }

    vulnerability = vulnerabilities.create!(attrs)
    vulnerability_reads.create!(
      vulnerability_id: vulnerability.id,
      project_id: project_id,
      scanner_id: scanner.id,
      report_type: vulnerability.report_type,
      severity: vulnerability.severity,
      state: 1,
      uuid: SecureRandom.uuid
    )
  end
end
