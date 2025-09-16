# frozen_string_literal: true

RSpec.shared_examples 'sync vulnerabilities changes to ES' do
  let(:received_vulnerabilities) { [] }

  before do
    allow(::Search::Elastic::VulnerabilityIndexingHelper).to receive(:vulnerability_indexing_allowed?).and_return(true)

    allow(Elastic::ProcessBookkeepingService).to receive(:track!) do |*vulnerabilities|
      received_vulnerabilities.concat(vulnerabilities)
    end
  end

  context 'for vulnerability es ingestion' do
    before do
      allow_next_found_instance_of(Vulnerability) do |instance|
        allow(instance).to receive(:maintaining_elasticsearch?).and_return(true)
      end

      allow_next_found_instance_of(Vulnerabilities::Read) do |instance|
        allow(instance).to receive(:maintaining_elasticsearch?).and_return(true)
      end
    end

    it 'calls the ProcessBookkeepingService with vulnerabilities' do
      subject

      expect(Elastic::ProcessBookkeepingService).to have_received(:track!).at_least(:once)

      expect(received_vulnerabilities.uniq).to match_array(expected_vulnerabilities)
    end
  end
end
