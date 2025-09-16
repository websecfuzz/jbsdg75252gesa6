# frozen_string_literal: true

module QA
  RSpec.describe 'Plan' do
    describe 'Contribution Analytics', product_group: :optimize do
      let(:group) { create(:group, path: "contribution_anayltics-#{SecureRandom.hex(8)}") }

      let(:project) { create(:project, name: 'contribution_analytics', group: group) }

      let(:issue) { create(:issue, project: project) }

      let(:mr) { create(:merge_request, project: project) }

      before do
        Flow::Login.sign_in

        issue.visit!

        work_item_enabled = Page::Project::Issue::Show.perform(&:work_item_enabled?)
        show_page_type = work_item_enabled ? Page::Project::WorkItem::Show : Page::Project::Issue::Show

        show_page_type.perform(&:click_close_issue_button)

        mr.visit!
        Page::MergeRequest::Show.perform(&:merge!)

        group.visit!
        Page::Group::Menu.perform(&:go_to_contribution_analytics)
      end

      it(
        'tests contributions',
        :aggregate_failures,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347765'
      ) do
        EE::Page::Group::ContributionAnalytics.perform do |analytics_page|
          expect { analytics_page.push_analytics_content }.to eventually_have_content('3 pushes')
                                                 .within(max_duration: 240, reload_page: analytics_page)
          expect { analytics_page.push_analytics_content }.to eventually_have_content('1 contributor')
                                                 .within(max_duration: 240, reload_page: analytics_page)
          expect { analytics_page.mr_analytics_content }.to eventually_have_content('1 created, 1 merged, 0 closed.')
                                                 .within(max_duration: 240, reload_page: analytics_page)
          expect { analytics_page.issue_analytics_content }.to eventually_have_content('1 created, 1 closed.')
                                                 .within(max_duration: 240, reload_page: analytics_page)
        end
      end
    end
  end
end
