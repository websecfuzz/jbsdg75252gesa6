# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestVulnerabilities::Create, feature_category: :vulnerability_management do
  def create_finding_map
    user = create(:user)
    pipeline = create(:ci_pipeline, user: user)
    report_finding = create(:ci_reports_security_finding)
    create(:finding_map, :with_finding, report_finding: report_finding, pipeline: pipeline)
  end

  let_it_be(:finding_maps) { [create_finding_map] }

  let(:vulnerability) { Vulnerability.last }

  subject { described_class.new(nil, finding_maps).execute }

  context 'with multiple pipelines' do
    let_it_be(:finding_maps) { Array.new(2).map { create_finding_map } }

    it 'uses user_id and project from pipeline' do
      subject

      created_vulnerabilities = Vulnerability.id_in(finding_maps.map(&:vulnerability_id))

      expect(created_vulnerabilities.size).to eq(2)
      expect(created_vulnerabilities.map(&:author_id)).to match_array(
        finding_maps.map { |finding_map| finding_map.pipeline.user_id })
      expect(created_vulnerabilities.map(&:project)).to match_array(finding_maps.map(&:project))
    end
  end

  context 'detected_at date for new records' do
    it 'is not empty' do
      subject

      expect(vulnerability.detected_at).not_to be_nil
    end
  end

  context 'vulnerability CVSS vectors' do
    let(:expected_hash) do
      { "vector" => "CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:L/I:L/A:N", "vendor" => "GitLab" }
    end

    it 'set the CVSS vectors' do
      subject

      expect(vulnerability.cvss.first).to eq(expected_hash)
    end
  end

  context 'vulnerability state' do
    it 'sets the state of the vulnerability to `detected`' do
      subject

      expect(vulnerability.state).to eq('detected')
    end
  end
end
