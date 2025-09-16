# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::External::File::Project, feature_category: :pipeline_composition do
  include RepoHelpers

  let_it_be(:context_project) { create(:project) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:context_user) { user }
  let(:context) { Gitlab::Ci::Config::External::Context.new(**context_params) }
  let(:project_file) { described_class.new(params, context) }
  let(:pipeline_policy_context) { nil }
  let(:context_params) do
    {
      project: context_project,
      sha: project.commit.sha,
      user: context_user,
      pipeline_policy_context: pipeline_policy_context
    }
  end

  before do
    allow_next_instance_of(Gitlab::Ci::Config::External::Context) do |instance|
      allow(instance).to receive(:check_execution_time!)
    end
  end

  describe '#valid?' do
    subject(:valid?) do
      Gitlab::Ci::Config::External::Mapper::Verifier.new(context).process([project_file])
      project_file.valid?
    end

    describe 'security_policy_management_project_access_allowed?' do
      include_context 'with pipeline policy context'

      let(:params) { { file: 'pipeline-execution-policy.yml', project: project.full_path } }
      let(:creating_policy_pipeline) { true }

      around do |example|
        create_and_delete_files(project,
          { '/pipeline-execution-policy.yml' => { compliance_job: { script: 'test' } }.to_yaml }) do
          example.run
        end
      end

      shared_examples_for 'user has no access to the project' do
        it 'returns false' do
          expect(valid?).to be(false)
          expect(project_file.error_message).to include("Project `#{project.full_path}` not found or access denied!")
        end
      end

      shared_examples_for 'user has access to the project' do
        it 'returns true' do
          expect(valid?).to be(true)
        end
      end

      context 'when user does not have permission to access file' do
        let(:context_user) { create(:user) }

        it_behaves_like 'user has no access to the project'

        context 'and project is a security policy project' do
          let_it_be(:security_orchestration_policy_configuration, reload: true) do
            create(:security_orchestration_policy_configuration, security_policy_management_project: project,
              project: context_project)
          end

          it_behaves_like 'user has access to the project'

          context 'and project is linked to the context project as a security policy project' do
            before_all do
              security_orchestration_policy_configuration.update!(project: context_project)
            end

            it_behaves_like 'user has access to the project'

            context 'when creating_policy_pipeline? is false' do
              let(:creating_policy_pipeline) { false }

              it_behaves_like 'user has no access to the project'
            end

            context 'when project forbids SPP repository access via project settings' do
              before do
                project.project_setting.update!(spp_repository_pipeline_access: false)
              end

              it_behaves_like 'user has no access to the project'
            end
          end
        end
      end
    end
  end
end
