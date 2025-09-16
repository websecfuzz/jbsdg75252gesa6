# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::SettingChangedUpdateWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  describe '#perform' do
    let(:project_ids) { [1, 2, 3] }
    let(:analyzer_type) { 'container_scanning' }

    before do
      allow(Security::AnalyzersStatus::SettingsBasedUpdateService).to receive(:execute)
    end

    it 'calls SettingsBasedUpdateService with given project_ids and analyzer_type' do
      worker.perform(project_ids, analyzer_type)
      expect(Security::AnalyzersStatus::SettingsBasedUpdateService)
        .to have_received(:execute).with(project_ids, analyzer_type)
    end

    context 'when project_ids is empty' do
      let(:project_ids) { [] }

      it 'doesnt call SettingsBasedUpdateService' do
        worker.perform(project_ids, analyzer_type)
        expect(Security::AnalyzersStatus::SettingsBasedUpdateService).not_to have_received(:execute)
      end
    end

    context 'when project_ids is nil' do
      let(:project_ids) { nil }

      it 'doesnt call SettingsBasedUpdateService' do
        worker.perform(project_ids, analyzer_type)
        expect(Security::AnalyzersStatus::SettingsBasedUpdateService).not_to have_received(:execute)
      end
    end

    context 'when analyzer_type is empty' do
      let(:analyzer_type) { '' }

      it 'doesnt call SettingsBasedUpdateService' do
        worker.perform(project_ids, analyzer_type)
        expect(Security::AnalyzersStatus::SettingsBasedUpdateService).not_to have_received(:execute)
      end
    end

    context 'when analyzer_type is nil' do
      let(:analyzer_type) { nil }

      it 'doesnt call SettingsBasedUpdateService' do
        worker.perform(project_ids, analyzer_type)
        expect(Security::AnalyzersStatus::SettingsBasedUpdateService).not_to have_received(:execute)
      end
    end

    context 'when both project_ids and analyzer_type are not present' do
      let(:project_ids) { [] }
      let(:analyzer_type) { nil }

      it 'doesnt call SettingsBasedUpdateService' do
        worker.perform(project_ids, analyzer_type)
        expect(Security::AnalyzersStatus::SettingsBasedUpdateService).not_to have_received(:execute)
      end
    end
  end
end
