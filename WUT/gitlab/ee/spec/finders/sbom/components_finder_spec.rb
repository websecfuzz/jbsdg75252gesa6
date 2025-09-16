# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentsFinder, feature_category: :vulnerability_management do
  let(:finder) { described_class.new(group, query) }
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }
  let_it_be(:project) { create(:project, namespace: group) }

  let_it_be(:component_1) { create(:sbom_component, name: "activerecord") }
  let_it_be(:component_2) { create(:sbom_component, name: "component-a") }
  let_it_be(:component_3) { create(:sbom_component, name: "component-b") }
  let_it_be(:component_4) { create(:sbom_component, name: "buuba") }

  let_it_be(:version_1) { create(:sbom_component_version, component: component_1) }
  let_it_be(:version_2) { create(:sbom_component_version, component: component_2) }
  let_it_be(:version_3) { create(:sbom_component_version, component: component_3) }
  let_it_be(:version_4) { create(:sbom_component_version, component: component_4) }

  let_it_be(:occurrence_1) { create(:sbom_occurrence, component_version: version_1, project: project) }
  let_it_be(:occurrence_2) { create(:sbom_occurrence, component_version: version_2, project: project) }
  let_it_be(:occurrence_3) { create(:sbom_occurrence, component_version: version_3, project: project) }
  let_it_be(:occurrence_4) { create(:sbom_occurrence, component_version: version_4, project: project) }

  describe '#execute' do
    before do
      stub_const("Sbom::Component::DEFAULT_COMPONENT_NAMES_LIMIT", 3)
    end

    subject(:find) { finder.execute }

    context 'when given no query string' do
      let(:query) { nil }

      it "returns all names up to limit", :aggregate_failures do
        expect(find.length).to eq(3)
        expect(find).to eq([component_1, component_4, component_2])
      end
    end

    context 'when given a query string' do
      let(:query) { "active" }

      it "returns all matching names" do
        expect(find).to match_array([component_1])
      end
    end
  end
end
