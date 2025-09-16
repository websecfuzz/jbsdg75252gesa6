# frozen_string_literal: true

module QA
  # Add :smoke back once proven reliable
  RSpec.describe 'Plan', product_group: :product_planning do
    describe 'Epics Management' do
      include_context 'work item epics migration'

      let(:group) { create(:group, name: "group-to-test-epics-#{SecureRandom.hex(4)}") }

      before do
        Flow::Login.sign_in
      end

      it 'creates an epic', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347980' do
        epic_title = 'Epic created via GUI'
        if work_item_epics_enabled_for_group?(group)
          EE::Resource::WorkItemEpic.fabricate_via_browser_ui! do |epic|
            epic.group = group
            epic.title = epic_title
          end
        else
          EE::Resource::Epic.fabricate_via_browser_ui! do |epic|
            epic.group = group
            epic.title = epic_title
          end
        end

        expect(page).to have_content(epic_title)
      end

      it 'creates a confidential epic', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347979' do
        epic_title = 'Confidential epic created via GUI'
        if work_item_epics_enabled_for_group?(group)
          EE::Resource::WorkItemEpic.fabricate_via_browser_ui! do |epic|
            epic.group = group
            epic.title = epic_title
            epic.confidential = true
          end
        else
          EE::Resource::Epic.fabricate_via_browser_ui! do |epic|
            epic.group = group
            epic.title = epic_title
            epic.confidential = true
          end
        end

        expect(page).to have_content(epic_title)
        expect(page).to have_content("Marked as confidential.")
      end

      context 'when resources created via API' do
        let(:issue) { create_issue_resource }
        let(:epic) { create_epic_resource(issue.project.group) }

        context 'when visit epic first' do
          before do
            epic.visit!
          end

          it 'adds/removes issue to/from epic',
            testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347983' do
            if EE::Page::Group::WorkItem::Epic::Show.perform(&:work_item_epic?)
              EE::Page::Group::WorkItem::Epic::Show.perform do |show|
                show.add_child_issue_to_epic(issue)

                expect(show).to have_child_issue_item

                show.remove_child_issue_from_epic(issue)

                expect(show).to have_no_child_issue_item
              end
            else
              EE::Page::Group::Epic::Show.perform do |show|
                show.add_issue_to_epic(issue.web_url)

                expect(show).to have_related_issue_item

                show.remove_issue_from_epic

                expect(show).to have_no_related_issue_item
              end
            end
          end

          it 'comments on epic', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347982' do
            comment = 'My Epic Comment'
            if EE::Page::Group::WorkItem::Epic::Show.perform(&:work_item_epic?)
              EE::Page::Group::WorkItem::Epic::Show.perform do |show|
                show.comment(comment)

                expect(show).to have_comment(comment)
              end
            else
              EE::Page::Group::Epic::Show.perform do |show|
                show.comment(comment)

                expect(show).to have_comment(comment)
              end
            end
          end

          it 'closes and reopens an epic',
            testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347984' do
            if EE::Page::Group::WorkItem::Epic::Show.perform(&:work_item_epic?)
              EE::Page::Group::WorkItem::Epic::Show.perform do |show|
                show.close_epic

                expect { show.has_system_note?('closed') }.to eventually_be_truthy.within(max_duration: 60),
                  "Expected 'closed' system note but it did not appear."

                show.reopen_epic

                expect { show.has_system_note?('opened') }.to eventually_be_truthy.within(max_duration: 60),
                  "Expected 'opened' system note but it did not appear."
              end
            else
              EE::Page::Group::Epic::Show.perform do |show|
                show.close_epic

                expect { show.has_system_note?('closed') }.to eventually_be_truthy.within(max_duration: 60),
                  "Expected 'closed' system note but it did not appear."

                show.reopen_epic

                expect { show.has_system_note?('opened') }.to eventually_be_truthy.within(max_duration: 60),
                  "Expected 'opened' system note but it did not appear."
              end
            end
          end
        end

        it 'adds/removes issue to/from epic using quick actions',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347981' do
          issue.visit!

          work_item_enabled = Page::Project::Issue::Show.perform(&:work_item_enabled?)

          if work_item_enabled
            Page::Project::WorkItem::Show.perform do |show|
              show.wait_for_child_items_to_load
              show.comment("/set_parent #{issue.project.group.web_url}/-/epics/#{epic.iid}")
              show.comment("/remove_parent")
            end
          else
            Page::Project::Issue::Show.perform do |show|
              show.wait_for_related_issues_to_load
              show.comment("/epic #{issue.project.group.web_url}/-/epics/#{epic.iid}")
              show.comment("/remove_epic")
            end
          end

          epic.visit!

          if EE::Page::Group::WorkItem::Epic::Show.perform(&:work_item_epic?)
            EE::Page::Group::WorkItem::Epic::Show.perform do |show|
              expect(show).to have_system_note(/(added)([\w\-# ]+)(issue)/)
              expect(show).to have_system_note('removed')
            end
          else
            EE::Page::Group::Epic::Show.perform do |show|
              expect(show).to have_system_note('added')
              expect(show).to have_system_note('removed')
            end
          end
        end

        def create_issue_resource
          project = create(:project, :private, name: 'project-for-issues', description: 'project for adding issues')

          create(:issue, project: project)
        end

        def create_epic_resource(group)
          begin
            epic = create(:work_item_epic, group: group, title: 'Work Item Epic created via API')
          rescue ArgumentError, NotImplementedError
            epic = create(:epic, group: group, title: 'Epic created via API')
          else
            update_web_url(group, epic)
          end
          epic
        end
      end
    end
  end
end
