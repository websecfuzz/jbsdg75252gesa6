# frozen_string_literal: true

module QA
  RSpec.describe 'Security Risk Management', product_group: :security_insights do
    describe 'Security Reports in a Merge Request Widget' do
      let(:sast_vuln_count) { 8 }
      let(:dependency_scan_vuln_count) { 4 }
      let(:container_scan_vuln_count) { 8 }
      let(:vuln_name) { "Regular Expression Denial of Service in debug" }
      let(:remediable_vuln_name) do
        "Authentication bypass via incorrect DOM traversal and canonicalization in saml2-js"
      end

      let(:project) do
        create(:project,
          :with_readme,
          add_name_uuid: false,
          name: "project-create-mr-secure-#{SecureRandom.hex(6)}",
          description: 'Project with Secure')
      end

      let(:source_branch) { "secure-mr-#{SecureRandom.hex(6)}" }

      let!(:runner) do
        create(:project_runner, project: project, name: "qa-runner-#{SecureRandom.hex(6)}",
          tags: %w[secure_report])
      end

      after do
        runner.remove_via_api! if runner
      end

      before do
        Flow::Login.sign_in

        # Push fixture to generate Secure reports
        source = Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.directory = Pathname.new(EE::Runtime::Path.fixture('secure_premade_reports'))
          push.commit_message = 'Create Secure compatible application to serve premade reports'
          push.branch_name = source_branch
        end

        merge_request = create(:merge_request,
          project: project,
          source_branch: source_branch,
          target_branch: project.default_branch,
          source: source,
          target: project.default_branch,
          target_new_branch: false)

        project.visit!
        Flow::Pipeline.wait_for_latest_pipeline(status: 'Passed', wait: 90)

        merge_request.visit!
      end

      it 'displays vulnerabilities in merge request widget', :smoke,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348031' do
        Page::MergeRequest::Show.perform do |merge_request|
          # skip test when mr_reports_tab FF is enabled as it is WIP
          # https://gitlab.com/gitlab-org/gitlab/-/issues/466223
          skip('mr_reports_tab FF is WIP') if merge_request.has_reports_tab?

          expect(merge_request).to have_vulnerability_report
          expect(merge_request).to have_vulnerability_count

          merge_request.expand_vulnerability_report

          expect(merge_request).to have_sast_vulnerability_count_of(sast_vuln_count)
          expect(merge_request).to have_dependency_vulnerability_count_of(dependency_scan_vuln_count)
          expect(merge_request).to have_container_vulnerability_count_of(container_scan_vuln_count)
          expect(merge_request).to have_dast_vulnerability_count
        end
      end
    end
  end
end
