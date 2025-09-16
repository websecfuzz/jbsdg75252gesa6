# frozen_string_literal: true

require 'spec_helper'
require './ee/spec/services/sbom/exporters/file_helper'

RSpec.describe Sbom::Exporters::JsonArrayService, feature_category: :dependency_management do
  include FileHelper

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }

  describe '.combine_parts' do
    let(:part_1) do
      stub_file('{"a": "b"}')
    end

    let(:part_2) do
      stub_file('{"b": "c"}')
    end

    subject(:combined_parts) { described_class.combine_parts([part_1, part_2]) }

    after do
      part_1.close!
      part_2.close!
    end

    it 'combines the parts into a flat array' do
      expect(combined_parts).to eq(
        <<~JSON
        [
          {"a": "b"},
          {"b": "c"}
        ]
        JSON
      )
    end
  end

  describe '#generate' do
    let(:sbom_occurrences) { Sbom::Occurrence.for_namespace_and_descendants(group).order_by_id }
    let(:service_class) { described_class.new(nil, sbom_occurrences) }

    subject(:dependencies) { Gitlab::Json.parse(service_class.generate) }

    before do
      stub_licensed_features(dependency_scanning: true)
    end

    context 'when the group does not have dependencies' do
      it { is_expected.to be_empty }
    end

    context 'when the group has dependencies' do
      let_it_be(:bundler) { create(:sbom_component, :bundler) }
      let_it_be(:bundler_v1) { create(:sbom_component_version, component: bundler, version: "1.0.0") }

      let_it_be(:occurrence_1) { create(:sbom_occurrence, :mit, project: project) }
      let_it_be(:occurrence_2) { create(:sbom_occurrence, :apache_2, project: project) }
      let_it_be(:occurrence_3) { create(:sbom_occurrence, :apache_2, :mpl_2, project: project) }

      let_it_be(:occurrence_of_bundler_v1) do
        create(:sbom_occurrence, :mit, project: project, component: bundler, component_version: bundler_v1)
      end

      let_it_be(:other_occurrence_of_bundler_v1) do
        create(:sbom_occurrence, :mit, project: project, component: bundler, component_version: bundler_v1)
      end

      it 'includes each occurrence excluding archived projects' do
        expect(dependencies).to eq([
          {
            "name" => occurrence_1.component_name,
            "version" => occurrence_1.version,
            "packager" => occurrence_1.package_manager,
            "licenses" => occurrence_1.licenses,
            "location" => occurrence_1.location.as_json
          },
          {
            "name" => occurrence_2.component_name,
            "version" => occurrence_2.version,
            "packager" => occurrence_2.package_manager,
            "licenses" => occurrence_2.licenses,
            "location" => occurrence_2.location.as_json
          },
          {
            "name" => occurrence_3.component_name,
            "version" => occurrence_3.version,
            "packager" => occurrence_3.package_manager,
            "licenses" => occurrence_3.licenses,
            "location" => occurrence_3.location.as_json
          },
          {
            "name" => occurrence_of_bundler_v1.component_name,
            "version" => occurrence_of_bundler_v1.version,
            "packager" => occurrence_of_bundler_v1.package_manager,
            "licenses" => occurrence_of_bundler_v1.licenses,
            "location" => occurrence_of_bundler_v1.location.as_json
          },
          {
            "name" => other_occurrence_of_bundler_v1.component_name,
            "version" => other_occurrence_of_bundler_v1.version,
            "packager" => other_occurrence_of_bundler_v1.package_manager,
            "licenses" => other_occurrence_of_bundler_v1.licenses,
            "location" => other_occurrence_of_bundler_v1.location.as_json
          }
        ])
      end
    end
  end

  describe '#generate_part' do
    let_it_be(:occurrences_by_name) do
      [
        create(:sbom_occurrence, :mit, project: project),
        create(:sbom_occurrence, :apache_2, project: project)
      ].index_by(&:component_name)
    end

    subject(:data) { described_class.new(nil, project.sbom_occurrences).generate_part }

    def json_data(object)
      occurrence = occurrences_by_name[object['name']]

      {
        'name' => occurrence.component_name,
        'packager' => occurrence.package_manager,
        'version' => occurrence.version,
        'licenses' => occurrence.licenses,
        'location' => occurrence.location.stringify_keys
      }
    end

    it 'writes data with one JSON object per line' do
      # JSON does not have ordering guarantees so we need to parse the
      # data to ensure a consistent result.
      stream = StringIO.new(data)
      stream.each_line do |line|
        object = Gitlab::Json.parse(line)
        expect(object).to eq(json_data(object))
      end
    end

    xit 'does not have N+1 queries' do # rubocop:disable RSpec/PendingWithoutReason -- TODO: Sbom::Occurrence#has_dependency_paths? has an n+1 query which is unavoidable for now
      control = ActiveRecord::QueryRecorder.new { described_class.new(nil, project.sbom_occurrences).generate_part }

      create(:sbom_occurrence, :mit, project: project)

      expect { described_class.new(nil, project.sbom_occurrences).generate_part }.not_to exceed_query_limit(control)
    end
  end
end
