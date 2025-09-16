# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Sort labels', :js, feature_category: :team_planning do
  include ListboxHelpers

  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let!(:label1) { create(:group_label, title: 'Foo', description: 'Lorem ipsum', group: group) }
  let!(:label2) { create(:group_label, title: 'Bar', description: 'Fusce consequat', group: group) }

  before do
    group.add_maintainer(user)
    sign_in(user)

    visit group_labels_path(group)
  end

  it 'sorts by title by default' do
    expect(page).to have_button('Name')

    # assert default sorting
    within '.other-labels' do
      expect(page.all('.js-label-list-item').first.text).to include('Bar')
      expect(page.all('.js-label-list-item').last.text).to include('Foo')
    end
  end

  it 'sorts by date' do
    click_button 'Name'

    expect_listbox_items([
      'Name',
      'Name, descending',
      'Last created',
      'Oldest created',
      'Updated date',
      'Oldest updated'
    ])

    select_listbox_item('Name, descending')

    # assert default sorting
    within '.other-labels' do
      expect(page.all('.js-label-list-item').first.text).to include('Foo')
      expect(page.all('.js-label-list-item').last.text).to include('Bar')
    end
  end
end
