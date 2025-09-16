# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::Ingestion::CveEnrichment::CveEnrichmentIngestionTask, feature_category: :software_composition_analysis do
  describe '.execute' do
    let(:cve_id) { 'CVE-2023-12345' }
    let(:new_epss_score) { 0.75 }
    let(:old_epss_score) { 0.5 }
    let(:new_is_known_exploit) { true }
    let(:default_is_known_exploit) { false }

    let!(:existing_cve_enrichment) do
      create(:pm_cve_enrichment, cve: cve_id, epss_score: old_epss_score)
    end

    let(:import_data) do
      [
        build(:pm_cve_enrichment_data_object, cve_id: cve_id, epss_score: new_epss_score,
          is_known_exploit: new_is_known_exploit),
        build(:pm_cve_enrichment_data_object)
      ]
    end

    subject(:execute) { described_class.execute(import_data) }

    context 'when CVE enrichments are valid' do
      it 'adds all new CVE enrichments in import data' do
        expect { execute }.to change { PackageMetadata::CveEnrichment.count }.from(1).to(2)
      end

      it 'updates existing CVE enrichments' do
        expect { execute }.to change { existing_cve_enrichment.reload.epss_score }
                                .from(old_epss_score)
                                .to(new_epss_score)
                                .and change { existing_cve_enrichment.reload.is_known_exploit }
                                       .from(default_is_known_exploit)
                                       .to(new_is_known_exploit)
      end

      it 'correctly stores the data for new and updated CVE enrichments' do
        result = execute

        expect(result).to contain_exactly(
          a_collection_including(
            cve_id,
            new_epss_score,
            new_is_known_exploit
          ),
          a_collection_including(
            import_data.last.cve_id,
            import_data.last.epss_score,
            import_data.last.is_known_exploit
          )
        )
      end
    end

    context 'when CVE enrichments are invalid' do
      let(:valid_cve_enrichment) { build(:pm_cve_enrichment_data_object) }
      let(:invalid_cve_enrichment) { build(:pm_cve_enrichment_data_object, cve_id: 'invalid') }
      let(:import_data) { [valid_cve_enrichment, invalid_cve_enrichment] }

      it 'creates only valid CVE enrichments' do
        expect { execute }.to change { PackageMetadata::CveEnrichment.count }.by(1)
      end

      it 'logs invalid CVE enrichments as an error' do
        expect(Gitlab::ErrorTracking)
          .to receive(:track_exception)
                .with(
                  an_instance_of(described_class::Error),
                  hash_including(
                    cve: 'invalid',
                    epss_score: invalid_cve_enrichment.epss_score,
                    is_known_exploit: invalid_cve_enrichment.is_known_exploit,
                    errors: { cve: ["is invalid"] }
                  )
                )
        execute
      end
    end
  end
end
