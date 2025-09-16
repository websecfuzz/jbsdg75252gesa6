# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::Checkpoint, type: :model, feature_category: :software_composition_analysis do
  let(:data_types) do
    {
      advisories: 1,
      licenses: 2,
      cve_enrichment: 3
    }
  end

  let(:version_formats) do
    {
      v1: 1,
      v2: 2
    }
  end

  describe 'enums' do
    it_behaves_like 'purl_types enum'
    it { is_expected.to define_enum_for(:data_type).with_values(data_types) }
    it { is_expected.to define_enum_for(:version_format).with_values(version_formats) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:purl_type) }
    it { is_expected.to validate_presence_of(:data_type) }
    it { is_expected.to validate_presence_of(:version_format) }

    it { is_expected.to validate_presence_of(:sequence) }
    it { is_expected.to validate_numericality_of(:sequence).only_integer }

    it { is_expected.to validate_presence_of(:chunk) }
    it { is_expected.to validate_numericality_of(:chunk).only_integer }

    it do
      create(:pm_checkpoint)

      is_expected.to validate_uniqueness_of(
        :purl_type
      ).scoped_to([:data_type, :version_format]).ignoring_case_sensitivity
    end
  end

  describe '.with_path_components' do
    let(:checkpoints) { create_list(:pm_checkpoint, Enums::Sbom::PURL_TYPES.length) }

    it 'returns the checkpoint for the given parameters' do
      checkpoints.each do |checkpoint|
        actual = described_class.with_path_components(checkpoint.data_type,
          checkpoint.version_format, checkpoint.purl_type)
        expect(actual).to eq(checkpoint)
      end
    end
  end

  describe '#update' do
    let(:data_type) { 'licenses' }
    let(:version_format) { 'v1' }
    let(:purl_type) { 'npm' }

    let!(:checkpoint) do
      create(:pm_checkpoint, data_type: 'licenses', version_format: 'v1', purl_type: 'npm',
        sequence: 0, chunk: 0)
    end

    subject(:update!) do
      described_class.find_by(data_type: data_type, version_format: version_format, purl_type: purl_type)
        &.update!(sequence: 1, chunk: 1)
    end

    context 'when all attributes are the same' do
      it 'updates the checkpoint' do
        expect { update! }.to change { [checkpoint.reload.sequence, checkpoint.reload.chunk] }
          .from([0, 0])
          .to([1, 1])
      end
    end

    context 'when an attribute differs' do
      context 'and it is data_type' do
        let(:data_type) { 'advisories' }

        it 'does not update the checkpoint' do
          expect { update! }.not_to change { [checkpoint.reload.sequence, checkpoint.reload.chunk] }
        end
      end

      context 'and it is version_format' do
        let(:version_format) { 'v2' }

        it 'does not update the checkpoint' do
          expect { update! }.not_to change { [checkpoint.reload.sequence, checkpoint.reload.chunk] }
        end
      end

      context 'and it is purl_type' do
        let(:purl_type) { 'maven' }

        it 'does not update the checkpoint' do
          expect { update! }.not_to change { [checkpoint.reload.sequence, checkpoint.reload.chunk] }
        end
      end
    end
  end
end

RSpec.describe PackageMetadata::NullCheckpoint, type: :model, feature_category: :software_composition_analysis do
  subject(:null_checkpoint) { described_class.new }

  describe '#update' do
    it 'accepts any number of arguments without raising an error' do
      # rubocop:disable Rails/SaveBang -- There is no `update!` method since NullCheckpoint isn't ActiveRecord
      expect { null_checkpoint.update }.not_to raise_error
      expect { null_checkpoint.update(sequence: 1, chunk: 2) }.not_to raise_error
      # rubocop:enable Rails/SaveBang
    end

    it 'returns nil' do
      expect(null_checkpoint.update).to be_nil
      expect(null_checkpoint.update(sequence: 1, chunk: 2)).to be_nil
    end
  end

  describe '#blank?' do
    it 'always returns true' do
      expect(null_checkpoint.blank?).to be true
    end
  end
end
