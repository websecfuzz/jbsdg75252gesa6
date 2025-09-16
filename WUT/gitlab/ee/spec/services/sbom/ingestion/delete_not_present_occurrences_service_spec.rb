# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::DeleteNotPresentOccurrencesService, feature_category: :dependency_management do
  let_it_be(:pipeline) { create(:ci_pipeline) }
  let_it_be(:project) { pipeline.project }
  let_it_be(:source) { create(:sbom_source) }

  subject(:execute) { described_class.execute(pipeline, ingested_ids) }

  describe '#execute' do
    shared_examples 'it no-ops with failed sbom jobs' do
      context 'when there are failed sbom jobs' do
        let(:options) { { artifacts: { reports: { cyclonedx: { foo: :bar } } } } }

        before do
          create(:ee_ci_build, :failed, pipeline: pipeline, options: options)
        end

        it 'does not effect occurence count' do
          expect { execute }.not_to change { Sbom::Occurrence.count }
        end

        it_behaves_like 'does not sync with elasticsearch when no vulnerabilities'
      end
    end

    context 'when project has occurrences' do
      let_it_be_with_reload(:occurrences) { create_list(:sbom_occurrence, 4, pipeline: pipeline, source: source) }

      context 'when all occurrences have been removed' do
        let(:ingested_ids) { [] }

        context 'when occurrences have associated vulnerabilities' do
          let(:vulnerabilities) { create_list(:vulnerability, 2, project: project) }
          let(:expected_vulnerability_ids) { vulnerabilities.map(&:id) }

          before do
            create(:sbom_occurrences_vulnerability, occurrence: occurrences[0], vulnerability: vulnerabilities[0])
            create(:sbom_occurrences_vulnerability, occurrence: occurrences[1], vulnerability: vulnerabilities[1])
            create(:sbom_occurrences_vulnerability, occurrence: occurrences[2], vulnerability: vulnerabilities[0])
          end

          it 'deletes matching occurrences' do
            expect { execute }.to change { project.sbom_occurrences.reload.count }.from(4).to(0)
          end

          it_behaves_like 'it syncs vulnerabilities with elasticsearch'
        end

        it_behaves_like 'it no-ops with failed sbom jobs'
      end

      context 'when a subset of occurrences have been removed' do
        let(:ingested_ids) { occurrences.sample(2).map(&:id) }
        let(:ingested_occurrences) { occurrences.select { |occ| ingested_ids.include?(occ.id) } }

        context 'when deleted occurrences have associated vulnerabilities' do
          let(:vulnerabilities) { create_list(:vulnerability, 4, project: project) }
          let(:deleted_occurrences) { occurrences.reject { |occ| ingested_ids.include?(occ.id) } }
          let!(:deleted_occurrence_vulnerabilities) do
            [
              create(:sbom_occurrences_vulnerability, occurrence: deleted_occurrences[0],
                vulnerability: vulnerabilities[0]),
              create(:sbom_occurrences_vulnerability, occurrence: deleted_occurrences[1],
                vulnerability: vulnerabilities[1])
            ]
          end

          let(:expected_vulnerability_ids) { deleted_occurrence_vulnerabilities.map(&:vulnerability_id) }

          before do
            create(:sbom_occurrences_vulnerability, occurrence: ingested_occurrences[0],
              vulnerability: vulnerabilities[2])
            create(:sbom_occurrences_vulnerability, occurrence: ingested_occurrences[1],
              vulnerability: vulnerabilities[3])
          end

          it 'deletes the non-ingested occurrences' do
            execute

            expect(project.sbom_occurrences.reload.map(&:id)).to match_array(ingested_ids)
          end

          it_behaves_like 'it syncs vulnerabilities with elasticsearch'
        end

        context 'when deleted occurrences have no associated vulnerabilities' do
          it 'deletes the non-ingested occurrences' do
            execute

            expect(project.sbom_occurrences.reload.map(&:id)).to match_array(ingested_ids)
          end

          it_behaves_like 'does not sync with elasticsearch when no vulnerabilities'
        end

        it_behaves_like 'it no-ops with failed sbom jobs'
      end
    end

    context 'when project has filtered out occurrence' do
      let_it_be_with_reload(:occurrences) do
        create_list(:sbom_occurrence, 4, :registry_occurrence, pipeline: pipeline)
      end

      let(:ingested_ids) { occurrences.sample(2).map(&:id) }

      it 'does not delete filtered out occurence' do
        expect { execute }.not_to change { project.sbom_occurrences.reload.count }
      end

      it_behaves_like 'does not sync with elasticsearch when no vulnerabilities'

      it_behaves_like 'it no-ops with failed sbom jobs'
    end
  end
end
