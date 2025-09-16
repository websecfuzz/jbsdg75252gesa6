# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Component, type: :model, feature_category: :dependency_management do
  let(:component_types) { { library: 0 } }

  describe 'enums' do
    it_behaves_like 'purl_types enum'
    it { is_expected.to define_enum_for(:component_type).with_values(component_types) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:component_type) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:occurrences) }
    it { is_expected.to belong_to(:organization) }
  end

  describe '.libraries scope' do
    let_it_be(:library_sbom_component) { create(:sbom_component, component_type: :library) }

    subject { described_class.libraries }

    it { is_expected.to include(library_sbom_component) }
  end

  describe '.by_purl_type_and_name scope' do
    let_it_be(:matching_sbom_component) { create(:sbom_component, purl_type: 'npm', name: 'component-1') }
    let_it_be(:non_matching_sbom_component) { create(:sbom_component, purl_type: 'golang', name: 'component-2') }

    subject { described_class.by_purl_type_and_name('npm', 'component-1') }

    it { is_expected.to include(matching_sbom_component) }
    it { is_expected.not_to include(non_matching_sbom_component) }
  end

  describe '.by_unique_attributes' do
    let_it_be(:matching_component) do
      create(:sbom_component, component_type: :library, purl_type: :npm, name: 'component-1')
    end

    let_it_be(:non_matching_component) do
      create(:sbom_component, component_type: :library, purl_type: :golang, name: 'component-2')
    end

    subject(:results) do
      described_class.by_unique_attributes('component-1', :npm, :library, matching_component.organization_id)
    end

    it 'returns only the matching component' do
      expect(results.to_a).to eq([matching_component])
    end
  end

  describe '.by_name' do
    let_it_be(:component_1) do
      create(:sbom_component, name: 'activesupport')
    end

    let_it_be(:component_2) do
      create(:sbom_component, name: 'activestorage')
    end

    let_it_be(:non_matching_component) do
      create(:sbom_component, name: 'log4j')
    end

    subject(:results) { described_class.by_name('actives') }

    it 'returns only the matching components' do
      expect(results).to match_array([component_1, component_2])
    end
  end

  describe '.by_namespace' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:component_1) { create(:sbom_component, name: "activerecord") }
    let_it_be(:occurrence_1) { create(:sbom_occurrence, component: component_1, project: project) }
    let_it_be(:component_2) { create(:sbom_component, name: "activesupport") }
    let_it_be(:occurrence) { create(:sbom_occurrence, component: component_2, project: project) }
    let_it_be(:duplicated_component) { create(:sbom_component, name: "activerecord") }
    let_it_be(:occurrence_for_duplicate) { create(:sbom_occurrence, component: duplicated_component, project: project) }

    subject(:results) { described_class.by_namespace(thing, query) }

    context 'when passed a Namespace' do
      let(:thing) { group }

      context 'when given a query string' do
        let(:query) { component_1.name }

        it 'returns matching components' do
          expect(results).to match_array([component_1])
        end
      end

      context 'when no query string is given' do
        let(:query) { nil }

        it 'returns all components' do
          names = results.map(&:name)
          expect(names).to match_array(%w[activerecord activesupport])
        end
      end
    end

    context 'when passed a project' do
      let(:thing) { project }

      context 'when given a query string' do
        let(:query) { component_1.name }

        it 'returns matching components' do
          names = results.map(&:name)
          expect(names).to match_array([query])
        end
      end

      context 'when no query string is given' do
        let(:query) { nil }

        it 'returns all components' do
          names = results.map(&:name)
          expect(names).to match_array(%w[activerecord activesupport])
        end
      end
    end

    context 'when given anything else' do
      let(:thing) { build(:user) }
      let(:query) { "active" }

      it 'returns no results' do
        expect(results).to be_empty
      end
    end
  end

  context 'with loose foreign key on sbom_components.organization_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:organization) }
      let_it_be(:model) { create(:sbom_component, organization: parent) }
    end
  end
end
