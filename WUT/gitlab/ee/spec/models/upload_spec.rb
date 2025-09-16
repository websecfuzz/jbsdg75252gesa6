# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Upload, feature_category: :geo_replication do
  include EE::GeoHelpers

  it { is_expected.to have_one(:upload_state).inverse_of(:upload).class_name('Geo::UploadState') }

  include_examples 'a verifiable model with a separate table for verification state' do
    let(:verifiable_model_record) { build(:upload) }
    let(:unverifiable_model_record) { build(:upload, store: ObjectStorage::Store::REMOTE) }
  end

  describe '.replicables_for_current_secondary' do
    using RSpec::Parameterized::TableSyntax

    # Selective sync is configured relative to the upload's model. Take care not
    # to specify a model_factory that contradicts factory.
    #
    # Permutations of sync_object_storage combined with object-stored-uploads
    # are tested in code, because the logic is simple, and to do it in the table
    # would quadruple its size and have too much duplication.
    where(:selective_sync_namespaces, :selective_sync_shards, :factory, :model_factory, :is_upload_included) do
      nil                  | nil            | [:upload]                    | [:project]               | true
      nil                  | nil            | [:upload, :issuable_upload]  | [:project]               | true
      nil                  | nil            | [:upload, :namespace_upload] | [:group]                 | true
      nil                  | nil            | [:upload, :favicon_upload]   | [:appearance]            | true
      # selective sync by shard
      nil                  | :model         | [:upload]                    | [:project]               | true
      nil                  | :other         | [:upload]                    | [:project]               | false
      nil                  | :model_project | [:upload, :namespace_upload] | [:group]                 | true
      nil                  | :other         | [:upload, :namespace_upload] | [:group]                 | false
      nil                  | :other         | [:upload, :favicon_upload]   | [:appearance]            | true
      # selective sync by namespace
      :model_parent        | nil            | [:upload]                    | [:project]               | true
      :model_parent_parent | nil            | [:upload]                    | [:project, :in_subgroup] | true
      :model               | nil            | [:upload, :namespace_upload] | [:group]                 | true
      :model_parent        | nil            | [:upload, :namespace_upload] | [:group, :nested]        | true
      :other               | nil            | [:upload]                    | [:project]               | false
      :other               | nil            | [:upload]                    | [:project, :in_subgroup] | false
      :other               | nil            | [:upload, :namespace_upload] | [:group]                 | false
      :other               | nil            | [:upload, :namespace_upload] | [:group, :nested]        | false
      :other               | nil            | [:upload, :favicon_upload]   | [:appearance]            | true
    end

    with_them do
      subject(:upload_included) { described_class.replicables_for_current_secondary(upload).exists? }

      let(:model) { create(*model_factory) } # rubocop:disable Rails/SaveBang
      let(:node) do
        create(
          :geo_node_with_selective_sync_for,
          model: model,
          namespaces: selective_sync_namespaces,
          shards: selective_sync_shards,
          sync_object_storage: sync_object_storage
        )
      end

      before do
        stub_current_geo_node(node)
      end

      context 'when sync object storage is enabled' do
        let(:sync_object_storage) { true }

        context 'when the upload is locally stored' do
          let(:upload) { create(*factory, model: model) }

          it { is_expected.to eq(is_upload_included) }
        end

        context 'when the upload is object stored' do
          let(:upload) { create(*factory, :object_storage, model: model) }

          it { is_expected.to eq(is_upload_included) }
        end
      end

      context 'when sync object storage is disabled' do
        let(:sync_object_storage) { false }

        context 'when the upload is locally stored' do
          let(:upload) { create(*factory, model: model) }

          it { is_expected.to eq(is_upload_included) }
        end

        context 'when the upload is object stored' do
          let(:upload) { create(*factory, :object_storage, model: model) }

          it { is_expected.to be_falsey }
        end
      end
    end
  end

  describe '.search' do
    let_it_be(:upload1) { create(:upload, checksum: '85418cc881d37d83c7e681bc43f63731bf0849e06dc59fa8fa2dcf5448a47b8e') }
    let_it_be(:upload2) { create(:upload, checksum: '27988b9096bf85f1a274a458a4ea8c3de143f84bb35ad6f2e4de1df165fa81a3') }
    let_it_be(:upload3) { create(:upload, checksum: '077c81a37eeb5eff42c30ea6f5141dd6bf768787788773aa94022002f4ccdbe5') }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(upload1, upload2, upload3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all records' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches by attributes' do
        context 'for checksum attribute' do
          it do
            result = described_class.search('077c81a37eeb5eff42c30ea6f5141dd6bf768787788773aa94022002f4ccdbe5')

            expect(result).to contain_exactly(upload3)
          end
        end
      end
    end
  end

  describe '#destroy' do
    subject { create(:upload, :namespace_upload, checksum: '8710d2c16809c79fee211a9693b64038a8aae99561bc86ce98a9b46b45677fe4') }

    context 'when running in a Geo primary node' do
      let_it_be(:primary) { create(:geo_node, :primary) }
      let_it_be(:secondary) { create(:geo_node) }

      it 'logs an event to the Geo event log when bulk removal is used', :sidekiq_inline do
        stub_current_geo_node(primary)

        expect { subject.model.destroy! }.to change(Geo::Event.where(replicable_name: :upload, event_name: :deleted), :count).by(1)

        payload = Geo::Event.where(replicable_name: :upload, event_name: :deleted).last.payload

        expect(payload['model_record_id']).to eq(subject.id)
        expect(payload['blob_path']).to eq(subject.relative_path)
        expect(payload['uploader_class']).to eq('NamespaceFileUploader')
      end
    end
  end

  describe '.destroy_for_associations!', :sidekiq_inline do
    let_it_be(:vulnerability_export) { create(:vulnerability_export, :with_csv_file) }
    let_it_be(:uploader) { AttachmentUploader }
    let_it_be(:user) { create(:user) }
    let_it_be(:other_upload) { create(:upload, model: user, uploader: uploader.to_s) }

    let_it_be(:records) { Vulnerabilities::Export.where(id: vulnerability_export.id) }

    it 'deletes the file from the file storage', :sidekiq_inline do
      files_to_delete = described_class
                          .where(model: vulnerability_export, uploader: uploader.to_s).all.map(&:absolute_path)

      expect { described_class.destroy_for_associations!(records, uploader) }
        .to change { files_to_delete.map { |f| File.exist?(f) }.uniq }.from([true]).to([false])
    end

    it 'deletes uploads associated with the given records and uploader' do
      expect { described_class.destroy_for_associations!(records, uploader) }
        .to change { Upload.where(model: vulnerability_export, uploader: uploader.to_s).count }
              .from(1).to(0)
    end

    it 'does not delete uploads that are not associated with the given records' do
      expect { described_class.destroy_for_associations!(records, uploader) }
        .not_to change { Upload.where(model: user, uploader: uploader.to_s).count }
    end

    it 'calls begin_fast_destroy and finalize_fast_destroy' do
      expect(described_class).to receive(:begin_fast_destroy).and_call_original
      expect(described_class).to receive(:finalize_fast_destroy).and_call_original

      described_class.destroy_for_associations!(records, uploader)
    end

    context 'when no records are provided' do
      it 'does not delete anything' do
        expect { described_class.destroy_for_associations!(nil, uploader) }
          .not_to change { Upload.count }
      end
    end
  end
end
