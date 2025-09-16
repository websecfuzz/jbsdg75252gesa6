# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "admin/geo/replicables/index", feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:user) { build_stubbed(:admin) }

  before do
    @replicator_class = Gitlab::Geo.replication_enabled_replicator_classes[0]
    @target_node = instance_double(GeoNode, id: 123, name: 'geo-test-node')
    allow(view).to receive(:current_user).and_return(user)
  end

  context 'when geo_replicables_filtered_list_view is enabled' do
    before do
      stub_feature_flags(geo_replicables_filtered_list_view: true)

      render
    end

    it 'renders page header through the PageHeadingComponent component' do
      expect(rendered).to have_content('Geo Replication - geo-test-node')
    end

    it 'does not render _replication_nav' do
      expect(rendered).not_to render_template(partial: 'admin/geo/shared/_replication_nav')
    end

    it 'does render #js-geo-replicable' do
      expect(rendered).to have_css('#js-geo-replicable')
    end
  end

  context 'when geo_replicables_filtered_list_view is disabled' do
    before do
      stub_feature_flags(geo_replicables_filtered_list_view: false)

      render
    end

    it 'renders page header through the _replication_nav partial' do
      expect(rendered).to have_content('Geo Replication - geo-test-node')
    end

    it 'does render _replication_nav' do
      expect(rendered).to render_template(partial: 'admin/geo/shared/_replication_nav')
    end

    it 'does render #js-geo-replicable' do
      expect(rendered).to have_css('#js-geo-replicable')
    end
  end
end
