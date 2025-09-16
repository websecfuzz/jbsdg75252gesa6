# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::UpdateTokenStatusWorker, feature_category: :secret_detection do
  describe '#perform' do
    subject(:perform) { described_class.new.perform(pipeline.id) }

    let(:project) { create(:project, :repository) }
    let(:pipeline) { create(:ci_pipeline, :success, project: project) }
    let(:service) { instance_double(Security::SecretDetection::UpdateTokenStatusService) }

    before do
      allow(Security::SecretDetection::UpdateTokenStatusService)
        .to receive(:new).and_return(service)
      allow(service).to receive(:execute_for_pipeline)
    end

    it 'delegates the call to UpdateTokenStatusService' do
      perform

      expect(Security::SecretDetection::UpdateTokenStatusService)
        .to have_received(:new)
      expect(service).to have_received(:execute_for_pipeline)
    end
  end
end
