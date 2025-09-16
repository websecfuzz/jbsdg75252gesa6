# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::IngestOccurrencesVulnerabilities, feature_category: :dependency_management do
  describe '#execute' do
    let_it_be(:pipeline) { build(:ci_pipeline) }

    let!(:finding_1) do
      create(
        :vulnerabilities_finding,
        :detected,
        :with_dependency_scanning_metadata,
        project: pipeline.project,
        file: occurrence_map_1.input_file_path,
        package: occurrence_map_1.name,
        version: occurrence_map_1.version,
        pipeline: pipeline
      )
    end

    let!(:finding_2) do
      create(
        :vulnerabilities_finding,
        :detected,
        :with_dependency_scanning_metadata,
        project: pipeline.project,
        file: occurrence_map_2.input_file_path,
        package: occurrence_map_2.name,
        version: occurrence_map_2.version,
        pipeline: pipeline
      )
    end

    let(:occurrence_map_1) do
      create(:sbom_occurrence_map, :for_occurrence_ingestion, :with_occurrence)
    end

    let(:occurrence_map_2) do
      create(:sbom_occurrence_map, :for_occurrence_ingestion, :with_occurrence)
    end

    let(:occurrence_maps) { [occurrence_map_1, occurrence_map_2] }

    subject(:ingest_occurrences_vulnerabilities) do
      described_class.execute(pipeline, occurrence_maps)
    end

    before do
      occurrence_map_1.vulnerability_ids = [finding_1.vulnerability_id]
      occurrence_map_2.vulnerability_ids = [finding_2.vulnerability_id]
    end

    it_behaves_like 'bulk insertable task'

    it 'is idempotent' do
      expect { described_class.execute(pipeline, occurrence_maps) }
        .to change { Sbom::OccurrencesVulnerability.count }.by(2)
      expect { described_class.execute(pipeline, occurrence_maps) }
        .not_to change { Sbom::OccurrencesVulnerability.count }
    end

    describe 'attributes' do
      it 'sets the correct attributes for the occurrence' do
        ingest_occurrences_vulnerabilities

        expect(Sbom::OccurrencesVulnerability.all).to match_array([
          an_object_having_attributes('sbom_occurrence_id' => occurrence_map_2.occurrence_id,
            'vulnerability_id' => finding_2.vulnerability_id),
          an_object_having_attributes('sbom_occurrence_id' => occurrence_map_1.occurrence_id,
            'vulnerability_id' => finding_1.vulnerability_id)
        ])
      end
    end

    context 'when there is an existing occurrence' do
      before do
        create(:sbom_occurrences_vulnerability,
          sbom_occurrence_id: occurrence_map_1.occurrence_id,
          vulnerability_id: finding_1.vulnerability_id)
      end

      it 'does not create a new record for the existing occurrence' do
        expect { ingest_occurrences_vulnerabilities }.to change { Sbom::OccurrencesVulnerability.count }.by(1)
      end
    end

    context 'when there is more than one vulnerability per occurrence' do
      before do
        finding = create(
          :vulnerabilities_finding,
          :detected,
          :with_dependency_scanning_metadata,
          project: pipeline.project,
          file: occurrence_map_1.input_file_path,
          package: occurrence_map_1.name,
          version: occurrence_map_1.version,
          pipeline: pipeline
        )
        occurrence_map_1.vulnerability_ids << finding.vulnerability_id
      end

      it 'creates all related occurrences_vulnerabilities' do
        expect { ingest_occurrences_vulnerabilities }.to change { Sbom::OccurrencesVulnerability.count }.by(3)
      end
    end

    context 'when there is no vulnerabilities' do
      let(:occurrence_map_3) { create(:sbom_occurrence_map, :for_occurrence_ingestion, :with_occurrence) }
      let(:occurrence_maps) { [occurrence_map_1, occurrence_map_2, occurrence_map_3] }

      it 'skips records without vulnerabilities' do
        expect { ingest_occurrences_vulnerabilities }.to change { Sbom::OccurrencesVulnerability.count }.by(2)
      end
    end

    describe 'elasticsearch synchronization' do
      let(:bulk_es_service) { instance_double(Vulnerabilities::BulkEsOperationService) }
      let(:vulnerability_1) { finding_1.vulnerability }
      let(:vulnerability_2) { finding_2.vulnerability }

      before do
        allow(Vulnerabilities::BulkEsOperationService).to receive(:new).and_return(bulk_es_service)
        allow(bulk_es_service).to receive(:execute)
      end

      context 'when there are associated vulnerabilities' do
        let(:expected_vulnerability_ids) { [vulnerability_1.id, vulnerability_2.id] }

        it_behaves_like 'it syncs vulnerabilities with elasticsearch'
      end

      context 'when no vulnerabilities are returned' do
        let(:occurrence_maps) { [] }

        it_behaves_like 'does not sync with elasticsearch when no vulnerabilities'
      end

      context 'when return_data is empty' do
        before do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:return_data).and_return([])
          end
        end

        it_behaves_like 'does not sync with elasticsearch when no vulnerabilities'
      end
    end

    describe '#after_ingest' do
      let(:task_instance) { described_class.new(pipeline, occurrence_maps) }

      context 'when return_data is present' do
        let(:vulnerability_ids) { [finding_1.vulnerability_id, finding_2.vulnerability_id] }

        before do
          allow(task_instance).to receive(:return_data).and_return(vulnerability_ids)
          allow(task_instance).to receive(:sync_elasticsearch)
        end

        it 'calls sync_elasticsearch with the correct vulnerabilities' do
          task_instance.send(:after_ingest)

          expect(task_instance).to have_received(:sync_elasticsearch).with(
            match_array([finding_1.vulnerability, finding_2.vulnerability])
          )
        end
      end

      context 'when return_data is not present' do
        before do
          allow(task_instance).to receive(:return_data).and_return(nil)
          allow(task_instance).to receive(:sync_elasticsearch)
        end

        it 'does not call sync_elasticsearch' do
          task_instance.send(:after_ingest)

          expect(task_instance).not_to have_received(:sync_elasticsearch)
        end
      end
    end
  end
end
