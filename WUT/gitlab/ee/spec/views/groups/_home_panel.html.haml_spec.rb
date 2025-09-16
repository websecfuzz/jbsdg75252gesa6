# frozen_string_literal: true

require 'spec_helper'
RSpec.describe 'groups/_home_panel', feature_category: :groups_and_projects do
  context 'when group is a top level group' do
    let(:group) { build_stubbed(:group) }

    before do
      assign(:group, group)
    end

    it 'renders the enable_duo_banner partial' do
      render

      expect(rendered).to render_template partial: 'groups/_enable_duo_banner'
    end
  end

  context 'when group is a sub group' do
    let(:group) { build_stubbed(:group, parent: build_stubbed(:group)) }

    before do
      assign(:group, group)
    end

    it 'renders the enable_duo_banner partial' do
      render

      expect(rendered).not_to render_template partial: 'groups/_enable_duo_banner'
    end
  end
end
