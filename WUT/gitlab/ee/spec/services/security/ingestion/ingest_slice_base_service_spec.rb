# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::IngestSliceBaseService, feature_category: :vulnerability_management do
  let_it_be(:pipeline) { create(:ci_pipeline) }
  let_it_be(:vulnerability_1) { create(:vulnerability) }
  let_it_be(:vulnerability_2) { create(:vulnerability) }

  let(:finding_map_1) { create(:finding_map, vulnerability: vulnerability_1) }
  let(:finding_map_2) { create(:finding_map, vulnerability: vulnerability_2) }
  let(:finding_maps) { [finding_map_1, finding_map_2] }

  let(:service_class) do
    Class.new(described_class) do
      const_set(:SEC_DB_TASKS, %w[TaskOne])
      const_set(:MAIN_DB_TASKS, %w[TaskTwo])
    end
  end

  subject(:service) { service_class.new(pipeline, finding_maps) }

  before do
    stub_const('Security::Ingestion::Tasks::TaskOne', Class.new)
    stub_const('Security::Ingestion::Tasks::TaskTwo', Class.new)

    allow(Security::Ingestion::Tasks::TaskOne).to receive(:execute).and_return(true)
    allow(Security::Ingestion::Tasks::TaskTwo).to receive(:execute).and_return(true)
  end

  describe '#execute' do
    before do
      allow(::Search::Elastic::VulnerabilityIndexingHelper).to receive(
        :vulnerability_indexing_allowed?).and_return(false)
    end

    it 'executes all tasks and returns the vulnerability IDs' do
      expect(Security::Ingestion::Tasks::TaskOne).to receive(:execute).with(
        pipeline, finding_maps, an_instance_of(Security::Ingestion::Context))
      expect(Security::Ingestion::Tasks::TaskTwo).to receive(:execute).with(
        pipeline, finding_maps, an_instance_of(Security::Ingestion::Context))

      result = service.execute

      expect(result).to contain_exactly(vulnerability_1.id, vulnerability_2.id)
    end
  end

  describe '#update_elasticsearch' do
    before do
      allow(service).to receive(:vulnerability_ids).and_return(
        [vulnerability_1.id, vulnerability_2.id])
    end

    context 'when vulnerability indexing is allowed' do
      before do
        allow(::Search::Elastic::VulnerabilityIndexingHelper).to receive(
          :vulnerability_indexing_allowed?).and_return(true)

        allow(Vulnerability).to receive_message_chain(:includes,
          :where).and_return([vulnerability_1, vulnerability_2])
      end

      context 'for maintaining_elasticsearch?' do
        it 'updates elasticsearch only for eligible vulnerabilities' do
          allow(vulnerability_1).to receive(:maintaining_elasticsearch?).and_return(true)
          allow(vulnerability_2).to receive(:maintaining_elasticsearch?).and_return(false)

          expect(::Elastic::ProcessBookkeepingService).to receive(
            :track!).with(vulnerability_1)
          expect(::Elastic::ProcessBookkeepingService).not_to receive(
            :track!).with(vulnerability_2)

          service.send(:update_elasticsearch)
        end

        it 'does not update elasticsearch when all vulnerabilities are ineligible' do
          allow(vulnerability_1).to receive(:maintaining_elasticsearch?).and_return(false)
          allow(vulnerability_2).to receive(:maintaining_elasticsearch?).and_return(false)

          expect(::Elastic::ProcessBookkeepingService).not_to receive(
            :track!).with(an_instance_of(Vulnerability))

          service.send(:update_elasticsearch)
        end
      end
    end

    context 'when vulnerability indexing is disallowed' do
      before do
        allow(::Search::Elastic::VulnerabilityIndexingHelper).to receive(
          :vulnerability_indexing_allowed?).and_return(false)
      end

      it 'does not update elasticsearch for any vulnerabilities' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)

        service.send(:update_elasticsearch)
      end
    end
  end
end
