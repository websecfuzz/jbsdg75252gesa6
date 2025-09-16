# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::AdvantagesListComponent, :aggregate_failures, type: :component, feature_category: :acquisition do
  subject(:component) { described_class.new }

  it 'renders the component with all expected elements' do
    render_inline(component)

    within(find_by_testid('trial-reassurances-column')) do
      expect(page).to have_css('img')
    end

    expect(page).to have_content(s_('InProductMarketing|Experience the power of Ultimate + GitLab Duo Enterprise'))
    expect(page).to have_content(s_('InProductMarketing|No credit card required.'))

    expected_advantage_count = 5
    expect(all_by_testid('advantage-item').count).to eq(expected_advantage_count)
    expect(all_by_testid('check-circle-icon').count).to eq(expected_advantage_count)
  end
end
