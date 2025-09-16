# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Maven virtual registries', feature_category: :virtual_registry do
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
    sign_in(user)
  end

  describe 'list page' do
    subject(:url) { group_virtual_registries_maven_registries_path(group) }

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
    end

    context 'when user is maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'virtual registry is unavailable'
    end

    context 'with existing virtual registry', :aggregate_failures, :js do
      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }

      shared_examples 'page is accessible' do
        it 'passes accessibility tests' do
          visit url
          wait_for_requests
          expect(page).to be_axe_clean
        end
      end

      context 'when user is a group member' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'page is accessible'

        it 'renders maven virtual registry page without actions to create/edit' do
          visit url

          expect(page).to have_selector('h1', text: 'Maven virtual registries')
          expect(page).not_to have_link('Create registry',
            href: new_group_virtual_registries_maven_registry_path(group))

          expect(page).not_to have_link('Edit', href:
            edit_group_virtual_registries_maven_registry_path(group, registry))
          expect(page).to have_link(registry.name, href:
            group_virtual_registries_maven_registry_path(group, registry))
        end
      end

      context 'when user is maintainer' do
        before_all do
          group.add_maintainer(user)
        end

        it_behaves_like 'page is accessible'

        it 'renders maven virtual registry page with actions to create/edit' do
          visit url

          expect(page).to have_selector('h1', text: 'Maven virtual registries')
          expect(page).to have_link('Create registry', href: new_group_virtual_registries_maven_registry_path(group))

          expect(page).to have_link('Edit', href:
            edit_group_virtual_registries_maven_registry_path(group, registry))
          expect(page).to have_link(registry.name, href:
            group_virtual_registries_maven_registry_path(group, registry))
        end
      end
    end
  end

  describe 'new page' do
    subject(:url) { new_group_virtual_registries_maven_registry_path(group) }

    context 'when user is not group member' do
      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is guest' do
      before_all do
        group.add_guest(user)
      end

      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is a group member' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'virtual registry is unavailable'

      it 'allows creation of new maven virtual registry', :aggregate_failures do
        visit url

        expect(page).to have_selector('h1', text: 'New maven virtual registry')
        fill_in 'Name', with: 'test maven registry'
        fill_in 'Description (optional)', with: 'This is a test maven registry'
        click_button 'Create registry'

        expect(page).to have_current_path(group_virtual_registries_maven_registry_path(group,
          ::VirtualRegistries::Packages::Maven::Registry.last))
        expect(page).to have_title('test maven registry')
        expect(page).to have_content('Maven virtual registry was created')
      end

      it 'shows error when virtual registry name is too long', :aggregate_failures do
        visit url

        expect(page).to have_selector('h1', text: 'New maven virtual registry')
        fill_in 'Name', with: 'test maven registry' * 20
        click_button 'Create registry'
        expect(page).to have_content('Name is too long (maximum is 255 characters)')
      end

      it 'passes accessibility tests', :js do
        visit url

        wait_for_requests

        expect(page).to be_axe_clean
      end
    end
  end

  describe 'edit page' do
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }

    subject(:url) { edit_group_virtual_registries_maven_registry_path(group, registry) }

    context 'when user is not group member' do
      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is guest' do
      before_all do
        group.add_guest(user)
      end

      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is a group member', :aggregate_failures do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'virtual registry is unavailable'

      it 'allows updating existing maven virtual registry' do
        visit url

        expect(page).to have_selector('h1', text: 'Edit registry')
        fill_in 'Name', with: 'test maven registry'
        fill_in 'Description (optional)', with: 'This is a test maven registry'
        click_button 'Save changes'

        expect(page).to have_current_path(group_virtual_registries_maven_registry_path(group, registry))
        expect(page).to have_title('test maven registry')
        expect(page).to have_content('Maven virtual registry was updated')
      end

      it 'shows error when virtual registry name is too long' do
        visit url

        fill_in 'Name', with: 'test maven registry' * 20
        click_button 'Save changes'

        expect(page).to have_content('Name is too long (maximum is 255 characters)')
      end

      it 'allows deletion', :js do
        visit url

        click_button 'Delete registry'
        within_modal do
          click_button('Delete')
        end

        expect(page).to have_current_path(group_virtual_registries_maven_registries_path(group))
        expect(page).to have_content('Maven virtual registry was deleted')
      end

      it 'passes accessibility tests', :js do
        visit url

        wait_for_requests

        expect(page).to be_axe_clean
      end
    end
  end
end
