# frozen_string_literal: true

require 'spec_helper'
require './ee/spec/services/sbom/exporters/file_helper'

RSpec.describe Sbom::Exporters::CsvService, feature_category: :dependency_management do
  include FileHelper

  let_it_be(:project) { create(:project) }
  let_it_be(:export) { build_stubbed(:dependency_list_export) }
  let_it_be(:sbom_occurrences) { Sbom::Occurrence.all }

  let(:service_class) { described_class.new(export, sbom_occurrences) }

  describe '.header' do
    subject { described_class.header }

    it 'returns correct headers' do
      is_expected.to eq(
        "Name,Version,Packager,Location,License Identifiers,Project,Vulnerabilities Detected,Vulnerability IDs\n")
    end
  end

  describe '.combine_parts' do
    let(:header) do
      "Name,Version,Packager,Location,License Identifiers,Project,Vulnerabilities Detected,Vulnerability IDs"
    end

    let(:part_1) do
      stub_file("#{header}\naccepts,1.3.5,npm,/enterprise/node/-/blob/" \
        "9e800c181208cc6539b4d257096921af79c86653/package-lock.json,\"\",enterprise/node,0,\"\"\n")
    end

    let(:part_2) do
      stub_file("#{header}\nacorn,3.3.0,npm,/enterprise/node/-/blob/" \
        "9e800c181208cc6539b4d257096921af79c86653/package-lock.json,\"\",enterprise/node,0,\"\"\n")
    end

    subject(:combined_parts) { described_class.combine_parts([part_1, part_2]) }

    after do
      part_1.close!
      part_2.close!
    end

    it 'combines the parts with header' do
      expect(combined_parts).to eq(
        <<~CSV
        #{header}
        accepts,1.3.5,npm,/enterprise/node/-/blob/9e800c181208cc6539b4d257096921af79c86653/package-lock.json,"",enterprise/node,0,""
        acorn,3.3.0,npm,/enterprise/node/-/blob/9e800c181208cc6539b4d257096921af79c86653/package-lock.json,"",enterprise/node,0,""
        CSV
      )
    end
  end

  context 'when block is not given' do
    it 'renders csv to string' do
      expect(service_class.generate).to be_a String
    end
  end

  context 'when block is given' do
    it 'returns handle to Tempfile' do
      expect(service_class.generate { |file| file }).to be_a Tempfile
    end
  end

  describe '#generate' do
    subject(:csv) { CSV.parse(service_class.generate, headers: true) }

    let(:header) do
      [
        'Name',
        'Version',
        'Packager',
        'Location',
        'License Identifiers',
        'Project',
        'Vulnerabilities Detected',
        'Vulnerability IDs'
      ]
    end

    context 'when the organization does not have dependencies' do
      it { is_expected.to match_array([header]) }
    end

    context 'when the organization has dependencies' do
      let_it_be(:bundler) { create(:sbom_component, :bundler) }
      let_it_be(:bundler_v1) { create(:sbom_component_version, component: bundler, version: "1.0.0") }

      let_it_be(:occurrence) do
        create(:sbom_occurrence, :mit, :with_vulnerabilities,
          project: project,
          component: bundler,
          component_version: bundler_v1
        )
      end

      it 'returns correct content' do
        expect(csv[0]['Name']).to eq(occurrence.name)
        expect(csv[0]['Version']).to eq(occurrence.version)
        expect(csv[0]['Packager']).to eq(occurrence.package_manager)
        expect(csv[0]['Location']).to eq(occurrence.location[:blob_path])
        expect(csv[0]['License Identifiers']).to eq('MIT')
        expect(csv[0]['Project']).to eq(project.full_path)
        expect(csv[0]['Vulnerabilities Detected']).to eq('2')

        expected_vulnerabilities = occurrence.vulnerabilities.pluck(:id).join('; ')
        expect(csv[0]['Vulnerability IDs']).to eq(expected_vulnerabilities)
      end

      xit 'avoids N+1 queries' do # rubocop:disable RSpec/PendingWithoutReason -- TODO: Sbom::Occurrence#has_dependency_paths? has an n+1 query which is unavoidable for now
        control = ActiveRecord::QueryRecorder.new do
          service_class.generate
        end

        create_list(:sbom_occurrence, 3, :with_vulnerabilities,
          project: project, source: create(:sbom_source))

        expect do
          service_class.generate
        end.to issue_same_number_of_queries_as(control).or_fewer
      end
    end
  end
end
