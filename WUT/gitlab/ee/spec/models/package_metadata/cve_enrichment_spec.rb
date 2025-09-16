# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::CveEnrichment, type: :model, feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  subject(:cve_enrichment) { build(:pm_cve_enrichment) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:cve) }
    it { is_expected.to validate_presence_of(:epss_score) }
    it { is_expected.to validate_inclusion_of(:is_known_exploit).in_array([true, false]) }

    describe 'CVE format validation' do
      where(:attribute, :value, :is_valid) do
        :cve | 'CVE-1234-1234'                 | true
        :cve | 'CVE-2024-123456'               | true
        :cve | 'CVE-12-1234'                   | false
        :cve | 'CVE-1234-12345678901234567890' | false
        :cve | 'IAM-NOTA-CVE!'                 | false
      end

      with_them do
        subject(:cve_enrichment) { build(:pm_cve_enrichment, attribute => value).valid? }

        it { is_expected.to eq(is_valid) }
      end
    end
  end
end
