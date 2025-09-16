# frozen_string_literal: true

module QA
  module EE
    module Page
      module Registration
        class Welcome < QA::Page::Base
          view 'ee/app/views/registrations/welcome/show.html.haml' do
            element 'get-started-button'
            element 'role-dropdown'
          end

          view 'ee/app/views/registrations/welcome/_setup_for_company.html.haml' do
            element 'setup-for-just-me-content'
            element 'setup-for-just-me-radio'
          end

          view 'ee/app/views/registrations/welcome/_joining_project.html.haml' do
            element 'create-a-new-project-radio'
          end

          view 'ee/app/assets/javascripts/registrations/groups/new/components/group_project_fields.vue' do
            element 'group-name'
            element 'project-name'
          end

          def has_get_started_button?(wait: 0)
            has_element?('get-started-button', wait: wait)
          end

          def select_role(role)
            select_element('role-dropdown', role)
          end

          def choose_create_a_new_project_if_available
            click_element('create-a-new-project-radio') if has_element?('create-a-new-project-radio', wait: 1)
          end

          def choose_setup_for_just_me_if_available
            choose_element('setup-for-just-me-radio', true) if has_element?('setup-for-just-me-content', wait: 1)
          end

          def click_get_started_button
            Support::Retrier.retry_until do
              click_element 'get-started-button'

              wait_until(message: 'Waiting for get started button not to be rendered') do
                has_no_element?('get-started-button')
              end
            end
          end

          def create_initial_project(project: SecureRandom.hex(4), group: SecureRandom.hex(4))
            fill_element('group-name', group)
            fill_element('project-name', project)
            click_button("Create project")
          end
        end
      end
    end
  end
end
