# frozen_string_literal: true

module QA
  RSpec.describe 'Security Risk Management', product_group: :security_insights do
    describe 'Security Dashboard in a Project' do
      let!(:project) do
        create(:project, :with_readme, name: 'project-with-secure', description: 'Project with Secure')
      end

      let!(:label) { create(:project_label, project: project, title: "test severity 3") }
      let(:vuln_severity) { :CRITICAL }
      let(:vulnerabilities) do
        { "Gryffindor vulnerability": "Brave courageous and pompous vulnerability",
          "Ravenclaw vulnerability": "Witty and intelligent vulnerability",
          "Hufflepuff vulnerability": "Vulnerability with justice",
          Slytherin: "Cunning yet loyal vulnerability",
          "CVE-2017-18269 in glibc": "Short description to match in specs" }
      end

      let!(:vulnerability_report) do
        vulnerabilities.each do |name, description|
          Support::Retrier.retry_on_exception(
            sleep_interval: 2,
            message: "Retrying vulnerability create graphql api"
          ) do
            QA::EE::Resource::VulnerabilityItem.fabricate_via_api! do |vulnerability|
              vulnerability.id = project.id
              vulnerability.severity = vuln_severity
              vulnerability.name = name
              vulnerability.description = description
            end
          end
        end
      end

      let(:vulnerability_name) { "CVE-2017-18269 in glibc" }
      let(:vulnerability_description) { "Short description to match in specs" }
      let(:edited_vulnerability_issue_description) { "Test Vulnerability edited comment" }

      before do
        Flow::Login.sign_in
        project.visit!
      end

      it 'shows vulnerability details', :smoke,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348076' do
        Page::Project::Menu.perform(&:go_to_vulnerability_report)

        EE::Page::Project::Secure::SecurityDashboard.perform do |security_dashboard|
          expect(security_dashboard).to have_vulnerability(description: vulnerability_name)

          security_dashboard.click_vulnerability(description: vulnerability_name)
        end

        EE::Page::Project::Secure::VulnerabilityDetails.perform do |vulnerability_details|
          aggregate_failures "testing vulnerability details" do
            expect(vulnerability_details).to have_component(component_name: 'vulnerability-header')
            expect(vulnerability_details).to have_component(component_name: 'vulnerability-details')
            expect(vulnerability_details).to have_vulnerability_title(title: vulnerability_name)
            expect(vulnerability_details).to have_vulnerability_description(description: vulnerability_description)
            expect(vulnerability_details).to have_component(component_name: 'vulnerability-footer')
          end
        end
      end

      it(
        'creates an issue from vulnerability details', :smoke,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347683'
      ) do
        Page::Project::Menu.perform(&:go_to_vulnerability_report)

        EE::Page::Project::Secure::SecurityDashboard.perform do |security_dashboard|
          expect(security_dashboard).to have_vulnerability(description: vulnerability_name)

          security_dashboard.click_vulnerability(description: vulnerability_name)
        end

        EE::Page::Project::Secure::VulnerabilityDetails.perform do |vulnerability_details|
          expect(vulnerability_details).to have_vulnerability_title(title: vulnerability_name)

          vulnerability_details.click_create_issue_button
        end

        work_item_enabled = Page::Project::Issue::Show.perform(&:work_item_enabled?)
        new_page_type = work_item_enabled ? Page::Project::WorkItem::New : Page::Project::Issue::New
        show_page_type = work_item_enabled ? Page::Project::WorkItem::Show : Page::Project::Issue::Show

        new_page_type.perform do |new_page|
          new_page.fill_description(edited_vulnerability_issue_description)
          new_page.select_label(label)
          work_item_enabled ? new_page.create_new_work_item : new_page.create_new_issue
        end

        show_page_type.perform do |issue|
          aggregate_failures "testing edited vulnerability issue" do
            expect(issue).to have_issue_title("Investigate vulnerability: #{vulnerability_name}")
            expect(issue).to have_text(edited_vulnerability_issue_description)
            expect(issue).to have_label(label.title)
          end
        end
      end
    end
  end
end
