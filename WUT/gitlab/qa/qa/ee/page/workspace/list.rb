# frozen_string_literal: true

module QA
  module EE
    module Page
      module Workspace
        class List < QA::Page::Base
          view 'ee/app/assets/javascripts/workspaces/user/pages/list.vue' do
            element 'list-new-workspace-button'
          end

          view 'ee/app/assets/javascripts/workspaces/common/components/workspaces_list/empty_state.vue' do
            element 'new-workspace-button'
          end

          view 'ee/app/assets/javascripts/workspaces/common/components/workspaces_list/workspaces_list.vue' do
            element 'workspace-list-item'
          end

          view 'ee/app/assets/javascripts/workspaces/common/components/workspace_state_indicator.vue' do
            element 'workspace-state-indicator'
          end

          def has_empty_workspace?
            has_element?('new-workspace-button', skip_finished_loading_check: true)
          end

          def create_workspace(agent, project)
            existing_workspaces = []

            if has_empty_workspace?
              click_element('new-workspace-button', skip_finished_loading_check: true)
            else
              existing_workspaces = get_workspaces_list(tab: :active)
              click_element('list-new-workspace-button', skip_finished_loading_check: true)
            end

            QA::EE::Page::Workspace::New.perform do |new|
              new.select_devfile_project(project)
              new.select_cluster_agent(agent)
              new.add_new_variable('VAR1', 'value 1')
              new.save_workspace
            end

            Support::Waiter.wait_until(max_duration: 5, raise_on_failure: false) do
              get_workspaces_list(tab: :active).length > existing_workspaces.length
            end

            updated_workspaces = get_workspaces_list(tab: :active)

            workspace_name = (updated_workspaces - existing_workspaces).fetch(0, '').to_s

            raise "Workspace name is empty" if workspace_name == ''

            workspace_name
          end

          def click_terminated_tab
            find('a[role="tab"]', text: "Terminated", exact_text: true).click
          end

          def get_workspaces_list(tab:)
            within_element("workspace-tab-#{tab}".to_sym, skip_finished_loading_check: true) do
              all_elements('workspace-list-item', minimum: 0, skip_finished_loading_check: true)
                .flat_map { |element| element.text.scan(/(^workspace[^.\n]*)/) }.flatten
            end
          end

          def wait_for_workspaces_creation(workspace)
            within_element("#{workspace}-action".to_sym, skip_finished_loading_check: true) do
              Support::WaitForRequests.wait_for_requests(skip_finished_loading_check: false, finish_loading_wait: 180)
            end
          end

          def has_workspace_state?(workspace, state)
            within_element(workspace.to_s.to_sym, skip_finished_loading_check: true) do
              has_element?('workspace-state-indicator', title: state, skip_finished_loading_check: true, wait: 360)
            end
          end
        end
      end
    end
  end
end
