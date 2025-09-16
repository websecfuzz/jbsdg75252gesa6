# frozen_string_literal: true

module QA
  # This test uses `needs:project` premium feature,
  # it can only be run against an EE instance with an active license
  RSpec.describe 'Verify', product_group: :pipeline_authoring do
    describe 'Multi-project pipelines' do
      let(:downstream_job_name) { 'downstream_job' }
      let(:executor) { "qa-runner-#{SecureRandom.hex(4)}" }
      let!(:group) { create(:group) }

      let(:upstream_project) { create(:project, name: 'upstream-project', group: group) }
      let(:downstream_project) { create(:project, name: 'downstream-project', group: group) }

      let!(:runner) do
        create(:group_runner, group: group, name: executor, tags: [executor])
      end

      before do
        add_ci_file(downstream_project, downstream_ci_file)
        add_ci_file(upstream_project, upstream_ci_file)
        Flow::Pipeline.wait_for_pipeline_creation_via_api(project: upstream_project)
        Flow::Pipeline.wait_for_latest_pipeline_to_have_status(project: upstream_project, status: 'success')

        Flow::Login.sign_in
        upstream_project.visit_latest_pipeline
      end

      after do
        runner.remove_via_api!
      end

      it(
        'creates a multi-project pipeline with artifact download',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/358064'
      ) do
        Page::Project::Pipeline::Show.perform do |show|
          expect(show).not_to have_job(downstream_job_name)

          show.expand_linked_pipeline
          expect(show).to have_job(downstream_job_name)
        end
      end

      private

      def add_ci_file(project, file)
        create(:commit, project: project, commit_message: 'Add CI config file', actions: [file])
      end

      def upstream_ci_file
        {
          action: 'create',
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            stages:
             - test
             - deploy

            job1:
              stage: test
              tags: ["#{executor}"]
              script: echo 'done' > output.txt
              artifacts:
                paths:
                  - output.txt

            staging:
              stage: deploy
              trigger:
                project: #{downstream_project.path_with_namespace}
                strategy: depend
          YAML
        }
      end

      def downstream_ci_file
        {
          action: 'create',
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            "#{downstream_job_name}":
              stage: test
              tags: ["#{executor}"]
              needs:
                - project: #{upstream_project.path_with_namespace}
                  job: job1
                  ref: main
                  artifacts: true
              script: cat output.txt
          YAML
        }
      end
    end
  end
end
