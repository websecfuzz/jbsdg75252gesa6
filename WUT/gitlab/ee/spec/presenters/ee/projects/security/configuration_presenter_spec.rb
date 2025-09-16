# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::ConfigurationPresenter, feature_category: :software_composition_analysis do
  include Gitlab::Routing.url_helpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:presenter) { described_class.new(project, current_user: current_user) }

  describe '#to_h' do
    subject(:result) { presenter.to_h }

    it 'includes the vulnerability archive export path' do
      expect(result[:vulnerability_archive_export_path]).to eq(
        "/api/v4/security/projects/#{project.id}/vulnerability_archive_exports"
      )
    end

    it 'reports security_training_enabled' do
      allow(project).to receive(:security_training_available?).and_return(true)

      expect(result[:security_training_enabled]).to be_truthy
    end

    it 'includes a default value for container_scanning_for_registry_enabled' do
      expect(result[:container_scanning_for_registry_enabled]).to eq(false)
    end

    it 'includes a default value for secret_push_protection_enabled' do
      expect(result[:secret_push_protection_enabled]).to eq(false)
    end

    it 'includes a default value for validity_checks_enabled' do
      expect(result[:validity_checks_enabled]).to eq(false)
    end

    it 'includes validity_checks_available' do
      expect(result).to have_key(:validity_checks_available)
    end
  end

  describe '#to_html_data_attribute' do
    subject(:html_data) { presenter.to_html_data_attribute }

    before do
      stub_licensed_features(container_scanning_for_registry: true)
    end

    it 'includes container_scanning_for_registry feature information' do
      feature = Gitlab::Json.parse(html_data[:features]).find do |scan|
        scan['type'] == 'container_scanning_for_registry'
      end

      expect(feature['type']).to eq('container_scanning_for_registry')
      expect(feature['configured']).to eq(false)
      expect(feature['configuration_path']).to be_nil
      expect(feature['available']).to eq(true)
      expect(feature['can_enable_by_merge_request']).to eq(false)
      expect(feature['meta_info_path']).to be_nil
      expect(feature['security_features']).not_to be_empty
    end
  end
end
