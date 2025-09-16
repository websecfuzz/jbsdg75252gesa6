# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Virtual registry', feature_category: :virtual_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
    sign_in(user)
  end

  describe 'list page' do
    subject(:url) { group_virtual_registries_path(group) }

    context 'when user is not group member' do
      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is a group member' do
      before_all do
        group.add_guest(user)
      end

      it_behaves_like 'virtual registry is unavailable'

      it 'renders virtual registry page' do
        visit url

        expect(page).to have_selector('h1', text: 'Virtual registry')
      end
    end

    context 'when user has permissions' do
      before_all do
        group.add_maintainer(user)
      end

      it 'renders virtual registries page' do
        visit url

        expect(page).to have_selector('h1', text: 'Virtual registry')
      end

      it 'renders the empty state & button to create a new virtual registry' do
        visit url

        expect(page).to have_link('Create Maven registry',
          href: new_group_virtual_registries_maven_registry_path(group))
      end

      it 'passes accessibility tests', :js do
        visit url

        wait_for_requests

        expect(page).to be_axe_clean.skipping :'link-in-text-block'
      end

      context 'with an existing Maven virtual registry', :aggregate_failures do
        before do
          create(:virtual_registries_packages_maven_registry, group: group)
        end

        it 'renders virtual registries page' do
          visit url

          expect(page).to have_selector('h1', text: 'Virtual registry')
          expect(page).to have_text('Maven')
          expect(page).to have_link('View 1 registry', href: group_virtual_registries_maven_registries_path(group))
          expect(page).to have_link('Create registry', href: new_group_virtual_registries_maven_registry_path(group))
        end

        it 'passes accessibility tests', :js do
          visit url

          wait_for_requests

          expect(page).to be_axe_clean
        end
      end
    end
  end
end
