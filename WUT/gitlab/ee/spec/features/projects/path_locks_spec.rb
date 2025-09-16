# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Path Locks', :js, feature_category: :source_code_management do
  include Spec::Support::Helpers::ModalHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:project) { create(:project, :repository, namespace: user.namespace) }
  let(:tree_path) { project_tree_path(project, project.repository.root_ref) }

  before do
    project.add_maintainer(user)
    project.add_developer(other_user)
    sign_in(user)

    visit tree_path

    wait_for_requests
  end

  it 'locking folders' do
    within '.tree-content-holder' do
      click_link "encoding"
    end

    wait_for_requests

    click_button 'Lock'

    within_modal do
      click_button 'Ok'
    end

    expect(page).to have_button('Unlock')
  end

  it 'locking files' do
    page_tree = find('.tree-content-holder')

    within page_tree do
      click_link "VERSION"
    end

    within_testid('blob-controls') do
      click_button 'File actions'
      click_button 'Lock'
    end

    wait_for_requests

    within_modal do
      click_button 'Lock'
    end

    click_button 'File actions'
    expect(page).to have_button('Unlock')

    sign_in other_user
    visit project_blob_path(project, File.join('master', 'VERSION'))
    click_button 'File actions'
    expect(page).to have_button('Unlock', disabled: true)
  end

  it 'unlocking files' do
    within find('.tree-content-holder') do
      click_link "VERSION"
    end

    within_testid('blob-controls') do
      click_button 'File actions'
      click_button 'Lock'
    end

    wait_for_requests

    within_modal do
      click_button 'Lock'
    end

    within_testid('blob-controls') do
      click_button 'File actions'
      click_button 'Unlock'
    end

    within_modal do
      click_button 'Unlock'
    end

    click_button 'File actions'
    expect(page).to have_link('Lock')
  end

  it 'managing of lock list' do
    create :path_lock, path: 'encoding', user: user, project: project

    click_link "Locked files"

    within '.js-path-locks' do
      expect(page).to have_content('encoding')
    end

    click_link "Unlock"

    accept_gl_confirm('Are you sure you want to unlock encoding?')

    expect(page).not_to have_content('encoding')
  end
end
