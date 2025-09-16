# frozen_string_literal: true

module QA
  RSpec.describe 'Systems', :orchestrated, :requires_admin, :geo, product_group: :geo do
    describe 'CI job' do
      let(:file_name) { 'geo_artifact.txt' }
      let(:directory_name) { 'geo_artifacts' }
      let(:pipeline_job_name) { 'test-artifacts' }
      let(:executor) { "qa-runner-#{SecureRandom.hex(6)}" }

      let(:project) { create(:project, name: 'geo-project-with-artifacts') }
      let!(:runner) { create(:project_runner, project: project, name: executor, tags: [executor]) }

      before do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              test-artifacts:
                tags:
                  - '#{executor}'
                artifacts:
                  paths:
                    - '#{directory_name}'
                  expire_in: 1000 seconds
                script:
                  - |
                    mkdir #{directory_name}
                    echo "CONTENTS" > #{directory_name}/#{file_name}
            YAML
          }
        ])
      end

      after do
        runner.remove_via_api!
      end

      # Test code is based on qa/specs/features/browser_ui/4_verify/locked_artifacts_spec.rb
      it 'job logs are viewable on secondary Geo sites',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348010' do
        Runtime::Logger.debug('Visiting the secondary Geo site')

        Flow::Login.while_signed_in(address: :geo_secondary) do
          Page::Main::Menu.perform(&:go_to_projects)

          Page::Dashboard::Projects.perform do |dashboard|
            dashboard.wait_for_project_replication(project.name)
            dashboard.go_to_project(project.name)
          end

          Flow::Pipeline.visit_latest_pipeline(wait: QA::EE::Runtime::Geo.max_file_replication_time)

          Page::Project::Pipeline::Show.perform do |pipeline|
            pipeline.wait_for_pipeline_job_replication(pipeline_job_name)
            pipeline.click_job(pipeline_job_name)
          end

          Page::Project::Job::Show.perform do |pipeline_job|
            pipeline_job.wait_for_job_log_replication
            expect(pipeline_job).to have_job_log
          end
        end
      end

      it 'job artifacts are viewable on secondary Geo sites',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348006' do
        artifact_page_retry_attempts = 12

        Runtime::Logger.debug('Visiting the secondary Geo site')

        Flow::Login.while_signed_in(address: :geo_secondary) do
          Page::Main::Menu.perform(&:go_to_projects)

          Page::Dashboard::Projects.perform do |dashboard|
            dashboard.wait_for_project_replication(project.name)
            dashboard.go_to_project(project.name)
          end

          Flow::Pipeline.visit_latest_pipeline(wait: QA::EE::Runtime::Geo.max_file_replication_time)

          Page::Project::Pipeline::Show.perform do |pipeline|
            pipeline.wait_for_pipeline_job_replication(pipeline_job_name)
            pipeline.click_job(pipeline_job_name)
          end

          Page::Project::Job::Show.perform do |pipeline_job|
            pipeline_job.wait_for_job_artifact_replication
            pipeline_job.click_browse_button
          end

          Page::Project::Artifact::Show.perform do |artifact|
            artifact.go_to_directory(directory_name, artifact_page_retry_attempts)
            expect(artifact).to have_content(file_name)
          end
        end
      end
    end
  end
end
