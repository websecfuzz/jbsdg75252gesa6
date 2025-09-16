# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'prevent forking outside group',
      except: { pipeline: %i[staging staging-canary] }, product_group: :source_code do
      let!(:group_for_fork) do
        Resource::Sandbox.fabricate! do |sandbox_group|
          sandbox_group.path = "group_for_fork_#{SecureRandom.hex(8)}"
        end
      end

      let(:project) do
        Resource::Project.fabricate! do |project|
          project.name = "project_to_fork"
          project.initialize_with_readme = true
        end
      end

      after do
        project.group.sandbox.update_group_setting(group_setting: 'prevent_forking_outside_group', value: false)
      end

      context 'when disabled' do
        before do
          set_prevent_forking_outside_group('disabled')
        end

        it 'allows forking outside of group',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347870' do
          project.visit!

          Page::Project::Show.perform(&:fork_project)

          Page::Project::Fork::New.perform do |fork_new|
            fork_new.fork_project(group_for_fork.path)
          end

          Page::Project::Show.perform do |project_page|
            expect(project_page.forked_from?(project.name)).to be_truthy
          end
        end
      end

      context 'when enabled' do
        before do
          set_prevent_forking_outside_group('enabled')
        end

        it 'does not allow forking outside of group',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347872' do
          project.visit!

          Page::Project::Show.perform(&:fork_project)

          Page::Project::Fork::New.perform do |fork_new|
            namespaces = fork_new.get_list_of_namespaces
            root_namespace_full_path = project.group.full_path.split('/').first

            expect(namespaces).to all(start_with(root_namespace_full_path))
            expect(namespaces).not_to include(group_for_fork)
          end
        end
      end

      def set_prevent_forking_outside_group(enabled_or_disabled)
        Flow::Login.sign_in
        project.group.sandbox.visit!
        Page::Group::Menu.perform(&:go_to_general_settings)
        Page::Group::Settings::General.perform do |general_setting|
          general_setting.send(:"set_prevent_forking_outside_group_#{enabled_or_disabled}")
        end
      end
    end
  end
end
