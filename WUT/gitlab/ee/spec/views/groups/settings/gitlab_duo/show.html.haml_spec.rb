# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/gitlab_duo/show', feature_category: :ai_abstraction_layer do
  let(:group) { build_stubbed(:group) }

  before do
    assign(:group, group)

    allow(view).to receive(:duo_home_app_data).with(group).and_return({})
  end

  it 'renders the enable_duo_banner partial' do
    render

    expect(rendered).to render_template partial: 'groups/_enable_duo_banner'
  end
end
