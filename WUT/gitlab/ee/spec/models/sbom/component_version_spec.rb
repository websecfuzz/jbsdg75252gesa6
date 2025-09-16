# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentVersion, type: :model, feature_category: :dependency_management do
  describe 'associations' do
    it { is_expected.to belong_to(:component).required }
    it { is_expected.to have_many(:occurrences) }
    it { is_expected.to belong_to(:organization) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_length_of(:version).is_at_most(255) }
  end

  describe '.by_component_id_and_version' do
    let_it_be(:matching_version) { create(:sbom_component_version) }
    let_it_be(:non_matching_version) { create(:sbom_component_version) }

    subject(:results) do
      described_class.by_component_id_and_version(matching_version.component_id, matching_version.version)
    end

    it 'returns only the matching version' do
      expect(results.to_a).to eq([matching_version])
    end
  end

  context 'with loose foreign key on sbom_component_versions.organization_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:organization) }
      let_it_be(:model) { create(:sbom_component_version, organization: parent) }
    end
  end

  shared_examples 'fetching verions' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:sbom_component_1) { create(:sbom_component) }
    let_it_be(:component_version_1) { create(:sbom_component_version, component: sbom_component_1) }
    let_it_be(:sbom_component_2) { create(:sbom_component) }
    let_it_be(:component_version_2) { create(:sbom_component_version, component: sbom_component_2) }

    let_it_be(:occurrence_1) do
      create(:sbom_occurrence, project: project, component: sbom_component_1, component_version: component_version_1)
    end

    let_it_be(:occurrence_2) do
      create(:sbom_occurrence, project: project, component: sbom_component_2, component_version: component_version_2)
    end

    context 'when sbom occurences belongs to same component' do
      context 'when all the versions present are unique' do
        let_it_be(:component_version_3) { create(:sbom_component_version, component: sbom_component_1) }
        let_it_be(:occurrence_3) do
          create(:sbom_occurrence, project: project,
            component: sbom_component_1, component_version: component_version_3)
        end

        it 'returns the matching versions' do
          expect(results.to_a).to match_array([component_version_1, component_version_3])
        end
      end

      context 'when same version is present more than once' do
        let_it_be(:occurrence_4) do
          create(:sbom_occurrence, project: project,
            component: sbom_component_1, component_version: component_version_1)
        end

        it 'returns only the unique versions' do
          expect(results.to_a).to eq([component_version_1])
        end
      end
    end

    context 'when sbom occurences does not belong to same component' do
      it 'returns only the matching version' do
        expect(results.to_a).to eq([component_version_1])
      end
    end
  end

  describe '.by_project_and_component' do
    let(:component_name) { sbom_component_1.name }

    subject(:results) do
      described_class.by_project_and_component(project.id, component_name)
    end

    it_behaves_like 'fetching verions'
  end

  describe '.by_group_and_component' do
    let(:component_name) { sbom_component_1.name }

    subject(:results) do
      described_class.by_group_and_component(group, component_name)
    end

    it_behaves_like 'fetching verions'
  end
end
