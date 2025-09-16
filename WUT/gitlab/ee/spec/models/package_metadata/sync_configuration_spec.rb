# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::SyncConfiguration, feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  before do
    allow(File).to receive(:exist?).and_return(false)
  end

  describe 'configs based on enabled purl types' do
    let(:all_purl_types) { Enums::Sbom.purl_types.values }

    shared_examples_for 'it returns all enabled sync configs' do
      let(:purl_type_map) { Enums::Sbom.purl_types_numerical }
      before do
        stub_application_setting(package_metadata_purl_types: enabled_purl_types)
      end

      specify do
        expected = expected_purl_types.map do |purl_type|
          have_attributes(data_type: expected_data_type, storage_type: :gcp, base_uri: expected_bucket,
            version_format: 'v2', purl_type: purl_type_map[purl_type])
        end

        expect(configurations).to match_array(expected)
      end
    end

    context 'when syncing licenses' do
      let(:expected_data_type) { 'licenses' }
      let(:expected_bucket) { described_class::Location::LICENSES_BUCKET }

      subject(:configurations) { described_class.configs_for('licenses') }

      where(:enabled_purl_types, :expected_purl_types) do
        ref(:all_purl_types)  | ref(:all_purl_types)
        [1, 5]                | [1, 5]
        []                    | []
      end

      with_them do
        it_behaves_like 'it returns all enabled sync configs'
      end
    end

    context 'when syncing advisories' do
      let(:expected_data_type) { 'advisories' }
      let(:expected_bucket) { described_class::Location::ADVISORIES_BUCKET }

      subject(:configurations) { described_class.configs_for('advisories') }

      where(:enabled_purl_types, :expected_purl_types) do
        ref(:all_purl_types)  | ref(:all_purl_types)
        [1, 5]                | [1, 5]
        []                    | []
      end

      with_them do
        it_behaves_like 'it returns all enabled sync configs'
      end
    end
  end

  context 'when syncing an unsupported data type' do
    subject(:configurations!) { described_class.configs_for('foo') }

    specify do
      expect { configurations! }.to raise_error(NoMethodError)
    end
  end

  describe PackageMetadata::SyncConfiguration::Location do
    describe '.for_licenses' do
      subject { described_class.for_licenses }

      where(:filepath_exists, :old_filepath_exists, :expected_storage_type, :expected_base_uri) do
        true     | false   | :offline  | described_class::LICENSES_PATH
        false    | true    | :offline  | described_class::OLD_LICENSES_PATH
        true     | true    | :offline  | described_class::LICENSES_PATH
        false    | false   | :gcp      | described_class::LICENSES_BUCKET
      end

      with_them do
        before do
          allow(File).to receive(:exist?).with(described_class::LICENSES_PATH)
            .and_return(filepath_exists)
          allow(File).to receive(:exist?).with(described_class::OLD_LICENSES_PATH)
            .and_return(old_filepath_exists)
        end

        it { is_expected.to match_array([expected_storage_type, expected_base_uri]) }
      end
    end

    describe '.for_advisories' do
      subject { described_class.for_advisories }

      where(:filepath_exists, :expected_storage_type, :expected_base_uri) do
        true     | :offline  | described_class::ADVISORIES_PATH
        false    | :gcp      | described_class::ADVISORIES_BUCKET
      end

      with_them do
        before do
          allow(File).to receive(:exist?).with(described_class::ADVISORIES_PATH)
            .and_return(filepath_exists)
        end

        it { is_expected.to match_array([expected_storage_type, expected_base_uri]) }
      end
    end

    describe '.for_cve_enrichment' do
      subject { described_class.for_cve_enrichment }

      where(:filepath_exists, :expected_storage_type, :expected_base_uri) do
        true     | :offline  | described_class::CVE_ENRICHMENT_PATH
        false    | :gcp      | described_class::CVE_ENRICHMENT_BUCKET
      end

      with_them do
        before do
          allow(File).to receive(:exist?).with(described_class::CVE_ENRICHMENT_PATH)
            .and_return(filepath_exists)
        end

        it { is_expected.to match_array([expected_storage_type, expected_base_uri]) }
      end
    end
  end

  describe '.registry' do
    ::Enums::Sbom::PURL_TYPES.each do |purl_type, _|
      context "when purl type is #{purl_type}" do
        it "returns a non-default value" do
          expect(described_class.registry_id(purl_type)).not_to be_nil
        end
      end
    end
  end

  describe '#to_s' do
    subject { described_class.new('advisories', 'gcp', 'adv-bucket', 'v1', 'pypi').to_s }

    it { is_expected.to eq('advisories:gcp/adv-bucket/v1/pypi') }
  end
end
