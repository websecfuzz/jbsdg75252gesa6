# frozen_string_literal: true

module QA
  module EE
    module Page
      module Admin
        module Settings
          class Securityandcompliance < QA::Page::Base
            include QA::Page::Settings::Common

            view 'ee/app/helpers/ee/application_settings_helper.rb' do
              element 'gem-checkbox', "-checkbox" # rubocop:disable QA/ElementWithPattern -- Pattern to fetch workspace action dynamically
            end

            view 'ee/app/views/admin/application_settings/_license_compliance.html.haml' do
              element 'save-package-registry-button'
            end

            view 'ee/app/views/admin/application_settings/_secret_push_protection.html.haml' do
              element 'secret-push-protection-checkbox'
            end

            view 'ee/app/views/admin/application_settings/security_and_compliance.html.haml' do
              element 'admin-license-compliance-settings'
              element 'admin-secret-detection-settings'
            end

            def select_gem_checkbox
              expand_content('admin-license-compliance-settings') do
                check_element('gem-checkbox', true)
                click_element('save-package-registry-button')
              end
            end

            def click_secret_protection_setting_checkbox
              expand_content('admin-secret-detection-settings') do
                check_element('secret-push-protection-checkbox', true)
                click_button('Save changes')
              end
            end
          end
        end
      end
    end
  end
end
