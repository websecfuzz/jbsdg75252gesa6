# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Import multiple repositories by uploading a manifest file', :js, feature_category: :importers do
  let(:user) { create(:admin) }
  let(:group) { create(:group) }

  before do
    stub_feature_flags(new_project_creation_form: false)
    stub_application_setting(import_sources: ['manifest'])

    sign_in(user)

    group.add_owner(user)
  end

  it 'parses manifest file and list repositories' do
    visit new_import_manifest_path

    attach_file('manifest', Rails.root.join('spec/fixtures/aosp_manifest.xml'))
    click_on 'List available repositories'

    expect(page).to have_button('Import 660 repositories')
    expect(page).to have_content('https://android-review.googlesource.com/platform/build/blueprint')
  end

  it 'imports a project successfully', :sidekiq_inline, :js do
    visit new_import_manifest_path

    attach_file('manifest', Rails.root.join('spec/fixtures/aosp_manifest.xml'))
    click_on 'List available repositories'

    page.within(second_row) do
      click_on 'Import'
    end
    click_on 'Continue import'

    wait_for_requests

    page.within(second_row) do
      expect(page).to have_content 'Complete'
      expect(page).to have_content("#{group.full_path}/build/blueprint")
    end
  end

  it 'renders an error if the remote url scheme starts with javascript' do
    visit new_import_manifest_path

    attach_file('manifest', Rails.root.join('spec/fixtures/unsafe_javascript.xml'))
    click_on 'List available repositories'

    expect(page).to have_content 'Make sure the url does not start with javascript'
  end

  it 'renders an error if invalid file was provided' do
    visit new_import_manifest_path

    attach_file('manifest', Rails.root.join('spec/fixtures/banana_sample.gif'))
    click_on 'List available repositories'

    expect(page).to have_content 'The uploaded file is not a valid XML file.'
  end

  def second_row
    page.all('table tbody tr')[1]
  end
end
