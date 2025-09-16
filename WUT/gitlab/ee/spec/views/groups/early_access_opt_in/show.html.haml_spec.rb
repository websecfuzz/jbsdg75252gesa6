# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/early_access_opt_in/show', :saas, type: :view, feature_category: :code_suggestions do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group) { build_stubbed(:group) }

  before do
    assign(:group, group)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:can?).and_return(true)
    allow(view).to receive(:edit_group_path).and_return('/groups/edit')
    allow(view).to receive(:sign_up_group_early_access_opt_in_path).and_return('/groups/early_access_opt_in/sign_up')
    allow(view).to receive(:group_early_access_opt_in_path).and_return("/groups/#{group.id}/early_access_opt_in")

    render
  end

  it 'displays the correct title' do
    expect(rendered).to have_content('Confirm enrollment in the Early Access Program')
  end

  it 'displays the enrollment confirmation text' do
    expect(rendered).to have_content('By enrolling in the Early access program, you agree that GitLab may contact you')
  end

  it 'includes a link to the Communication Preference Center' do
    expect(rendered).to have_link('Communication Preference Center', href: 'https://about.gitlab.com/company/preference-center/')
  end

  it 'has a confirm enrollment button' do
    expect(rendered).to have_button('Confirm Enrollment',
      type: 'submit'
    )
  end

  it 'has a cancel button that links to the group edit page' do
    expect(rendered).to have_link('Cancel', href: '/groups/edit')
  end
end
