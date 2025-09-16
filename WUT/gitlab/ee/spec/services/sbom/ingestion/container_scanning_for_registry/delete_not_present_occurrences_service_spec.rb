# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::ContainerScanningForRegistry::DeleteNotPresentOccurrencesService, feature_category: :dependency_management do
  let_it_be(:pipeline) { create(:ci_pipeline) }
  let_it_be(:project) { pipeline.project }
  let_it_be(:source) { create(:sbom_source) }

  subject(:execute) { described_class.execute(pipeline, ingested_ids, source.id) }

  shared_examples 'it no-ops with failed sbom jobs' do
    context 'when there are failed sbom jobs' do
      let(:options) { { artifacts: { reports: { cyclonedx: { foo: :bar } } } } }

      before do
        create(:ee_ci_build, :failed, pipeline: pipeline, options: options)
      end

      it 'does not effect occurence count' do
        expect { execute }.not_to change { Sbom::Occurrence.count }
      end
    end
  end

  describe '#execute' do
    context 'when project has occurrences' do
      let_it_be_with_reload(:occurrences) { create_list(:sbom_occurrence, 4, pipeline: pipeline, source: source) }

      context 'when all occurrences have been removed' do
        let(:ingested_ids) { [] }

        it 'deletes all occurrences' do
          expect { execute }.to change { project.sbom_occurrences.reload.count }.from(4).to(0)
        end

        it_behaves_like 'it no-ops with failed sbom jobs'
      end

      context 'when a subset of occurrences have been removed' do
        let(:ingested_occurrences) { occurrences.sample(2) }
        let(:ingested_ids) { ingested_occurrences.map(&:id) }

        it 'deletes the non-ingested occurrences' do
          execute

          expect(project.sbom_occurrences.reload).to match_array(ingested_occurrences)
        end

        it_behaves_like 'it no-ops with failed sbom jobs'
      end
    end

    context 'when project has occurrences with multiple sources' do
      let_it_be(:another_source) { create(:sbom_source) }
      let_it_be_with_reload(:occurrences) do
        create_list(:sbom_occurrence, 4, :registry_occurrence, pipeline: pipeline, source: another_source)
      end

      let(:ingested_occurrences) { occurrences.sample(2) }
      let(:ingested_ids) { ingested_occurrences.map(&:id) }

      it 'does not delete occurences from another source' do
        expect { execute }.not_to change { project.sbom_occurrences.reload.count }
      end

      it_behaves_like 'it no-ops with failed sbom jobs'
    end
  end
end
