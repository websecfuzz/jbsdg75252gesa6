# frozen_string_literal: true

module QA
  module Page
    module Project
      module Issue
        class Show < Page::Base
          include Page::Component::Note
          include Page::Component::DesignManagement
          include Page::Component::Issuable::Sidebar
          include Page::Component::Issuable::Common

          # We need to check phone_layout? instead of mobile_layout? here
          # since tablets have the regular top navigation bar
          prepend Mobile::Page::Project::Issue::Show if Runtime::Env.phone_layout?

          view 'app/assets/javascripts/issuable/components/related_issuable_item.vue' do
            element 'remove-related-issue-button'
          end

          view 'app/assets/javascripts/issues/show/components/description.vue' do
            element 'gfm-content'
          end

          view 'app/assets/javascripts/issues/show/components/edit_actions.vue' do
            element 'issuable-save-button'
          end

          view 'app/assets/javascripts/issues/show/components/header_actions.vue' do
            element 'delete-issue-button'
            element 'desktop-dropdown'
            element 'edit-button'
            element 'issue-header'
            element 'toggle-issue-state-button'
          end

          view 'app/assets/javascripts/related_issues/components/related_issues_block.vue' do
            element 'related-issues-block'
          end

          view 'app/assets/javascripts/related_issues/components/related_issues_list.vue' do
            element 'related-issuable-content'
            element 'related-issues-loading-placeholder'
          end

          def work_item_enabled?
            Page::Project::Issue::Index.perform(&:work_item_enabled?)
          end

          def edit_description(new_description)
            within_element('issue-header') do
              click_element('edit-button')
            end

            fill_element('markdown-editor-form-field', new_description)
            click_element('issuable-save-button')
          end

          def relate_issue(issue)
            click_element('crud-form-toggle')
            fill_element('add-issue-field', issue.web_url)
            send_keys_to_element('add-issue-field', :enter)
          end

          def related_issuable_item
            find_element('related-issuable-content')
          end

          def wait_for_related_issues_to_load
            has_no_element?('related-issues-loading-placeholder', wait: QA::Support::Repeater::DEFAULT_MAX_WAIT_TIME)
          end

          def click_remove_related_issue_button
            retry_until(sleep_interval: 5) do
              click_element('remove-related-issue-button')
              has_no_element?('remove-related-issue-button', wait: QA::Support::Repeater::DEFAULT_MAX_WAIT_TIME)
            end
          end

          def click_close_issue_button
            open_actions_dropdown
            click_element('toggle-issue-state-button', text: 'Close issue')
          end

          def has_description?(description)
            find_element('gfm-content').text.include?(description)
          end

          def has_reopen_issue_button?
            open_actions_dropdown
            has_element?('toggle-issue-state-button', text: 'Reopen issue')
          end

          def has_delete_issue_button?
            open_actions_dropdown
            has_element?('delete-issue-button')
          end

          def has_no_delete_issue_button?
            open_actions_dropdown
            has_no_element?('delete-issue-button')
          end

          def has_issue_title?(title)
            wait_for_requests
            find_element('issue-title').text.include?(title)
          end

          def delete_issue
            has_delete_issue_button?
            click_element(
              'delete-issue-button',
              Page::Modal::DeleteIssue,
              wait: Support::Repeater::DEFAULT_MAX_WAIT_TIME
            )

            Page::Modal::DeleteIssue.perform(&:confirm_delete_issue)

            wait_for_requests
          end

          def open_actions_dropdown
            wait_for_requests
            # We use find here because these are gitlab-ui elements
            find('[data-testid="desktop-dropdown"] > button').click
          end
        end
      end
    end
  end
end

QA::Page::Project::Issue::Show.prepend_mod_with('Page::Project::Issue::Show', namespace: QA)
