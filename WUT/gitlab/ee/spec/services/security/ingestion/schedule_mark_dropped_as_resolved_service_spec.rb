# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::ScheduleMarkDroppedAsResolvedService,
  feature_category: :static_application_security_testing do
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, user: user) }

  let_it_be(:other_ident) { create(:vulnerabilities_identifier) }
  let_it_be(:untriaged_ident) { create(:vulnerabilities_identifier, external_type: 'find_sec_bugs_type') }

  let_it_be(:dismissed_ident) do
    create(:vulnerabilities_identifier, external_type: 'find_sec_bugs_type', external_id: 'PREDICTABLE_RANDOM')
  end

  let_it_be(:dropped_ident1) do
    create(:vulnerabilities_identifier, external_type: 'find_sec_bugs_type', external_id: 'OLD_PREDICTABLE_RANDOM_1')
  end

  let_it_be(:dropped_ident2) do
    create(:vulnerabilities_identifier, external_type: 'find_sec_bugs_type', external_id: 'OLD_PREDICTABLE_RANDOM_2')
  end

  before_all do
    # To remain untriaged (different scan_type)
    other_finding = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id,
      pipeline: pipeline, primary_identifier_id: other_ident.id, identifiers: [other_ident])
    create(
      :vulnerability,
      :detected,
      report_type: :dast,
      resolved_on_default_branch: true,
      project: pipeline.project,
      vulnerability_finding: other_finding, findings: [other_finding]
    ).tap do |vuln|
      other_finding.update!(vulnerability_id: vuln.id)
    end

    # To remain untriaged (same scan_type)
    untriaged_finding = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id,
      pipeline: pipeline, primary_identifier_id: untriaged_ident.id, identifiers: [untriaged_ident])
    create(
      :vulnerability,
      :detected,
      report_type: :sast,
      project: pipeline.project,
      vulnerability_finding: untriaged_finding, findings: [untriaged_finding]
    ).tap do |vuln|
      untriaged_finding.update!(vulnerability_id: vuln.id)
    end

    # To remain dismissed (same scan_type)
    dismissed_finding = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id,
      pipeline: pipeline, primary_identifier_id: dismissed_ident.id, identifiers: [dismissed_ident])
    create(
      :vulnerability,
      :dismissed,
      report_type: :sast,
      resolved_on_default_branch: true,
      project: pipeline.project,
      vulnerability_finding: dismissed_finding, findings: [dismissed_finding]
    ).tap do |vuln|
      dismissed_finding.update!(vulnerability_id: vuln.id)
    end

    # To be resolved (same scan_type)
    dropped_finding1 = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id,
      pipeline: pipeline, primary_identifier_id: dropped_ident1.id, identifiers: [dropped_ident1])
    create(
      :vulnerability,
      :detected,
      report_type: :sast,
      resolved_on_default_branch: true,
      project: pipeline.project,
      vulnerability_finding: dropped_finding1, findings: [dropped_finding1]
    ).tap do |vuln|
      dropped_finding1.update!(vulnerability_id: vuln.id)
    end

    # To be resolved (same scan_type)
    dropped_finding2 = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id,
      pipeline: pipeline, primary_identifier_id: dropped_ident1.id, identifiers: [dropped_ident1])
    create(
      :vulnerability,
      :detected,
      report_type: :sast,
      resolved_on_default_branch: true,
      project: pipeline.project,
      vulnerability_finding: dropped_finding2, findings: [dropped_finding2]
    ).tap do |vuln|
      dropped_finding2.update!(vulnerability_id: vuln.id)
    end

    # To be resolved (same scan_type, different identifier)
    dropped_finding3 = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id,
      pipeline: pipeline, primary_identifier_id: dropped_ident2.id, identifiers: [dropped_ident2])
    create(
      :vulnerability,
      :detected,
      report_type: :sast,
      resolved_on_default_branch: true,
      project: pipeline.project,
      vulnerability_finding: dropped_finding3, findings: [dropped_finding3]
    ).tap do |vuln|
      dropped_finding3.update!(vulnerability_id: vuln.id)
    end
  end

  subject(:service) { described_class.new(pipeline.project_id, 'sast', [untriaged_ident]).execute }

  before do
    stub_const("#{described_class.name}::BATCH_SIZE", 1)
  end

  it 'schedules MarkDroppedAsResolvedWorker' do
    expect { service }.to change { ::Vulnerabilities::MarkDroppedAsResolvedWorker.jobs.count }.by(2)

    expect(
      ::Vulnerabilities::MarkDroppedAsResolvedWorker.jobs.first['args']
    ).to eq([pipeline.project_id, [dropped_ident1.id]])
    expect(
      ::Vulnerabilities::MarkDroppedAsResolvedWorker.jobs.last['args']
    ).to eq([pipeline.project_id, [dropped_ident2.id]])
  end

  context 'when an error is raised' do
    before do
      allow(::Vulnerabilities::MarkDroppedAsResolvedWorker).to receive(:perform_in).and_raise(StandardError)
    end

    it 'tracks it' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        StandardError,
        project_id: pipeline.project_id,
        scan_type: 'sast',
        primary_identifiers: [untriaged_ident]
      )

      service
    end
  end

  context 'when primary_identifiers is empty' do
    subject(:service) { described_class.new(pipeline.project_id, 'sast', []).execute }

    it 'will not schedule a MarkDroppedAsResolvedWorker' do
      expect { service }.not_to change { ::Vulnerabilities::MarkDroppedAsResolvedWorker.jobs.count }
    end
  end

  context 'when primary_identifiers do not reference existing types' do
    subject(:service) { described_class.new(pipeline.project_id, 'sast', [dropped_ident1, dropped_ident2]).execute }

    it 'will not schedule a MarkDroppedAsResolvedWorker' do
      expect { service }.not_to change { ::Vulnerabilities::MarkDroppedAsResolvedWorker.jobs.count }
    end
  end
end
