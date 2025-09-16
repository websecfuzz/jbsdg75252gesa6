# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::Organization, feature_category: :organization do
  let_it_be_with_reload(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, organization: organization) }

  describe 'associations' do
    it { is_expected.to have_many(:vulnerability_exports).class_name('Vulnerabilities::Export') }
    it { is_expected.to have_many(:sbom_sources).class_name('Sbom::Source') }
    it { is_expected.to have_many(:sbom_source_packages).class_name('Sbom::SourcePackage') }
    it { is_expected.to have_many(:sbom_components).class_name('Sbom::Component') }
    it { is_expected.to have_many(:sbom_component_versions).class_name('Sbom::ComponentVersion') }
  end
end
