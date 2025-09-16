# frozen_string_literal: true

FactoryBot.define do
  factory :pm_cve_enrichment, class: 'PackageMetadata::CveEnrichment' do
    cve { "CVE-1234-12345" }
    epss_score { 12.34 }
    is_known_exploit { false }
  end
end
