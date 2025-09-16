# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::UploadReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:upload, :with_file) }

  include_examples 'a blob replicator'

  describe "#predownload_validation_failure" do
    context "when upload is valid and has an associated model/owner" do
      it "returns nil" do
        expect(replicator.predownload_validation_failure).to be_nil
      end
    end

    context "when upload is orphaned from its own model association" do
      before do
        # break the model association on the upload
        model_record.model_id = -1
        model_record.save!(validate: false)
        model_record.reload
      end

      it "returns an error string" do
        upload = model_record
        missing_model = "#{upload.model_type} ID##{upload.model_id}"
        expect(replicator.predownload_validation_failure).to eq(
          "The model which owns this Upload is missing. Upload ID##{upload.id}, #{missing_model}"
        )
      end
    end
  end

  describe "#calculate_checksum override" do
    context "when upload has an associated model/owner" do
      let(:upload_fixture_file_checksum) { 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }

      it "returns the upload file checksum" do
        expect(replicator.calculate_checksum).to eq(upload_fixture_file_checksum)
      end
    end

    context "when upload is orphaned from its own model association" do
      before do
        # break the model association on the upload
        model_record.model_id = -1
        model_record.save!(validate: false)
        model_record.reload
      end

      it "raises a clearer error" do
        upload = model_record
        missing_model = "#{upload.model_type} ID##{upload.model_id}"
        expect { replicator.calculate_checksum }.to raise_error(
          "The model which owns this Upload is missing. Upload ID##{upload.id}, #{missing_model}"
        )
      end
    end
  end

  describe "#model_is_missing_error_message" do
    context "when upload has an associated model/owner" do
      it "returns nil" do
        expect(replicator.model_is_missing_error_message).to be_nil
      end
    end

    context "when upload is orphaned from its own model association" do
      before do
        # break the model association on the upload
        model_record.model_id = -1
        model_record.save!(validate: false)
        model_record.reload
      end

      it "returns an error message" do
        upload = model_record
        missing_model = "#{upload.model_type} ID##{upload.model_id}"
        expect(replicator.model_is_missing_error_message).to eq(
          "The model which owns this Upload is missing. Upload ID##{upload.id}, #{missing_model}"
        )
      end
    end
  end
end
