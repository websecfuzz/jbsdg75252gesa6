# frozen_string_literal: true

module QA
  module EE
    module Page
      module Workspace
        class Action < QA::Page::Base
          view 'ee/app/assets/javascripts/workspaces/common/components/workspace_actions.vue' do
            element 'workspace-actions-dropdown'
            element 'workspace-button', ':data-testid="`workspace-${item.key}-button`"' # rubocop:disable QA/ElementWithPattern -- Pattern to fetch workspace action dynamically
          end

          view 'ee/app/assets/javascripts/workspaces/common/components/workspaces_list/workspaces_table.vue' do
            element 'workspace-action', ':data-testid="`${item.name}-action`"' # rubocop:disable QA/ElementWithPattern -- Pattern to fetch workspace name dynamically
          end

          def click_workspace_action(workspace, action)
            within_element("#{workspace}-action".to_sym, skip_finished_loading_check: true) do
              click_element("base-dropdown-toggle", skip_finished_loading_check: true)

              click_element("workspace-#{action}-button", skip_finished_loading_check: true)
            end
          end
        end
      end
    end
  end
end
