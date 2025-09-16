# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/security/dashboard/show.html.haml', feature_category: :vulnerability_management do
  def force_fluid_layout
    view.instance_variable_get(:@force_fluid_layout)
  end

  let(:group) { build_stubbed(:group) }

  before do
    assign(:group, group)
  end

  it 'renders the placeholder for the UI component' do
    render

    expect(rendered).to have_selector('#js-group-security-dashboard')
  end

  context 'when rendering the current security dashboard' do
    before do
      stub_feature_flags(group_security_dashboard_new: false)
    end

    it 'does not set the page to fluid layout' do
      render

      expect(force_fluid_layout).to be(false)
    end
  end

  context 'when rendering the new security dashboard' do
    before do
      stub_feature_flags(group_security_dashboard_new: true)
    end

    it 'sets the page to fluid layout' do
      render

      expect(force_fluid_layout).to be(true)
    end
  end
end
