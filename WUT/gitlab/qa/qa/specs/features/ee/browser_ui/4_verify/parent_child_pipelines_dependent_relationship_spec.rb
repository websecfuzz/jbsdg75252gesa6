# frozen_string_literal: true

module QA
  # This test uses `needs:project` premium feature,
  # it can only be run against an EE instance with an active license
  RSpec.describe 'Verify', product_group: :pipeline_execution do
    describe 'Parent-child pipelines dependent relationship' do
      let!(:project) { create(:project, name: 'pipelines-dependent-relationship') }
      let!(:runner) do
        create(:project_runner, project: project, name: project.name, tags: [project.name])
      end

      before do
        Flow::Login.sign_in
      end

      after do
        runner.remove_via_api!
      end

      it(
        'parent pipelines passes if child passes',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/358062'
      ) do
        add_ci_files(success_child_ci_file)
        Flow::Pipeline.visit_latest_pipeline

        Page::Project::Pipeline::Show.perform do |parent_pipeline|
          expect(parent_pipeline).to have_child_pipeline
          expect { parent_pipeline.has_passed? }.to eventually_be_truthy
        end
      end

      it(
        'parent pipeline fails if child fails',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/358063'
      ) do
        add_ci_files(fail_child_ci_file)
        Flow::Pipeline.visit_latest_pipeline

        Page::Project::Pipeline::Show.perform do |parent_pipeline|
          expect(parent_pipeline).to have_child_pipeline
          expect { parent_pipeline.has_failed? }.to eventually_be_truthy
        end
      end

      private

      def success_child_ci_file
        {
          action: 'create',
          file_path: '.child-ci.yml',
          content: <<~YAML
            child_job:
              stage: test
              tags: ["#{project.name}"]
              needs:
                - project: #{project.path_with_namespace}
                  job: job1
                  ref: main
                  artifacts: true
              script:
                - cat output.txt
                - echo "Child job done!"

          YAML
        }
      end

      def fail_child_ci_file
        {
          action: 'create',
          file_path: '.child-ci.yml',
          content: <<~YAML
            child_job:
              stage: test
              tags: ["#{project.name}"]
              script: exit 1

          YAML
        }
      end

      def parent_ci_file
        {
          action: 'create',
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            stages:
              - build
              - test
              - deploy

            default:
              tags: ["#{project.name}"]

            job1:
              stage: build
              script: echo "build success" > output.txt
              artifacts:
                paths:
                  - output.txt

            job2:
              stage: test
              trigger:
                include: ".child-ci.yml"
                strategy: depend

            job3:
              stage: deploy
              script: echo "parent deploy done"

          YAML
        }
      end

      def add_ci_files(child_ci_file)
        create(:commit, project: project, commit_message: 'Add parent and child pipelines CI files', actions: [
          child_ci_file, parent_ci_file
        ]).project.visit!
      end
    end
  end
end
