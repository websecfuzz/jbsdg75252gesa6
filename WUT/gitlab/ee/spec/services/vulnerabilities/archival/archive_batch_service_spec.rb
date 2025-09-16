# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::ArchiveBatchService, feature_category: :vulnerability_management do
  describe '.execute' do
    let(:mock_project) { instance_double(Project) }
    let(:batch) { [] }
    let(:mock_service_object) { instance_spy(described_class) }

    subject(:execute_archive_batch_logic) { described_class.execute(mock_project, batch) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates an object and delegates the call to it' do
      execute_archive_batch_logic

      expect(described_class).to have_received(:new).with(mock_project, batch)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:archive) { create(:vulnerability_archive, project: project) }
    let_it_be(:vulnerability) { create(:vulnerability, project: project) }
    let_it_be(:archived_record) do
      build(:vulnerability_archived_record,
        archive: archive,
        project: project,
        vulnerability_identifier: vulnerability.id,
        created_at: Time.zone.now,
        updated_at: Time.zone.now)
    end

    let(:service_object) { described_class.new(archive, project.vulnerabilities) }

    subject(:archive_vulnerabilities) { service_object.execute }

    before do
      allow(Vulnerabilities::Archival::ArchivedRecordBuilderService).to receive(:execute).and_return(archived_record)
      allow(Vulnerabilities::Statistics::AdjustmentWorker).to receive(:perform_async)
    end

    it 'archives the vulnerabilities' do
      expect { archive_vulnerabilities }.to change { Vulnerability.find_by_id(vulnerability.id) }.to(nil)
                                        .and change { archive.archived_records.count }.by(1)
                                        .and change { archive.reload.archived_records_count }.by(1)
    end

    it 'schedules the statistics adjustment worker' do
      archive_vulnerabilities

      expect(Vulnerabilities::Statistics::AdjustmentWorker).to have_received(:perform_async).with([project.id])
    end

    context 'when the archived record data contains unicode null character' do
      let(:archived_record) do
        build(:vulnerability_archived_record,
          :with_unicode_null_character,
          archive: archive,
          project: project,
          vulnerability_identifier: vulnerability.id,
          created_at: Time.zone.now,
          updated_at: Time.zone.now)
      end

      it 'archives the vulnerabilities' do
        expect { archive_vulnerabilities }.to change { Vulnerability.find_by_id(vulnerability.id) }.to(nil)
                                          .and change { archive.archived_records.count }.by(1)
                                          .and change { archive.reload.archived_records_count }.by(1)
      end
    end
  end
end
