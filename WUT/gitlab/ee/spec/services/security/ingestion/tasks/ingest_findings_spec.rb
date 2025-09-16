# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestFindings, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be(:pipeline) { create(:ci_pipeline) }
    let_it_be(:another_pipeline) { create(:ci_pipeline) }
    let_it_be(:identifier) { create(:vulnerabilities_identifier) }

    let(:finding_maps) { create_list(:finding_map, 4, identifier_ids: [identifier.id], pipeline: pipeline) }
    let!(:existing_finding) { create(:vulnerabilities_finding, :detected, uuid: finding_maps.first.uuid) }

    subject(:ingest_findings) { described_class.new(pipeline, finding_maps).execute }

    it 'ingests findings' do
      expect { ingest_findings }.to change { Vulnerabilities::Finding.count }.by(3)
    end

    it 'sets the finding and vulnerability ids' do
      expected_finding_ids = Array.new(3) { an_instance_of(Integer) }.unshift(existing_finding.id)
      expected_vulnerability_ids = [existing_finding.vulnerability_id, nil, nil, nil]

      expect { ingest_findings }.to change { finding_maps.map(&:finding_id) }.from(Array.new(4)).to(expected_finding_ids)
                               .and change { finding_maps.map(&:vulnerability_id) }.from(Array.new(4)).to(expected_vulnerability_ids)
    end

    context 'when considering the pipeline ids' do
      it 'properly sets initial and latest pipeline ids on the finding' do
        # latest_pipeline_id increases to 4 because the existing_finding is also updated
        expect { ingest_findings }.to change { Vulnerabilities::Finding.where(initial_pipeline_id: pipeline.id).count }.from(0).to(3)
                                        .and change { Vulnerabilities::Finding.where(latest_pipeline_id: pipeline.id).count }.from(0).to(4)
      end

      context 'when the finding is detected in subsequent pipelines' do
        subject(:ingest_findings) { described_class.new(another_pipeline, another_finding_maps).execute }

        let(:common_map_attrs) { { identifier_ids: [identifier.id], pipeline: another_pipeline } }
        let(:another_finding_maps) do
          finding_maps.map do |finding_map|
            Vulnerabilities::Finding.find(finding_map.finding_id)
              .then { |finding| common_map_attrs.merge(finding: finding) }
              # needed to prevent new findings from being created
              .then { |map_attrs| map_attrs.merge(security_finding: finding_map.security_finding) }
              .then { |map_attrs| create(:finding_map, **map_attrs) }
          end
        end

        before do
          described_class.new(pipeline, finding_maps).execute
        end

        it 'does not change the `initial_pipeline_id' do
          expect { ingest_findings }.not_to change { Vulnerabilities::Finding.where(initial_pipeline_id: pipeline.id).count }.from(3)
        end

        it 'updates the `latest_pipeline_id' do
          expect { ingest_findings }.to change { Vulnerabilities::Finding.where(latest_pipeline_id: another_pipeline.id).count }.from(0).to(4)
                                          .and change { Vulnerabilities::Finding.where(latest_pipeline_id: pipeline.id).count }.from(4).to(0)
        end
      end
    end

    context 'if attribute exceeds database limit' do
      before do
        %w[description solution].each do |attr|
          finding_maps.each do |finding_map|
            finding_map.report_finding.original_data[attr] = "a" * (Vulnerabilities::Finding::COLUMN_LENGTH_LIMITS[attr.to_sym] + 1)
          end
        end
      end

      it 'ingests findings' do
        expect { ingest_findings }.to change { Vulnerabilities::Finding.count }.by(3)
      end
    end

    it_behaves_like 'bulk insertable task'
  end
end
