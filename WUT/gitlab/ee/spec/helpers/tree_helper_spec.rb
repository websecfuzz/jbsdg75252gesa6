# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TreeHelper, feature_category: :source_code_management do
  include Devise::Test::ControllerHelpers

  let_it_be(:project_namespace) { build_stubbed(:project_namespace) }
  let_it_be(:project) { build_stubbed(:project, :repository, project_namespace: project_namespace) }
  let(:repository) { project.repository }
  let(:sha) { 'c1c67abbaf91f624347bb3ae96eabe3a1b742478' }

  let_it_be(:user) { build_stubbed(:user) }

  describe '#vue_tree_header_app_data' do
    let(:pipeline) { build_stubbed(:ci_pipeline, project: project) }
    let(:organization) { build_stubbed(:organization) }

    before do
      Current.organization = organization
      helper.instance_variable_set(:@project, project)
      helper.instance_variable_set(:@ref, sha)
    end

    subject { helper.vue_tree_header_app_data(project, repository, sha, pipeline) }

    it 'contains workspace data' do
      expect(helper.vue_tree_header_app_data(project, repository, sha, pipeline)).to include(
        new_workspace_path: new_remote_development_workspace_path,
        organization_id: organization.id
      )
    end

    context 'when alternative_kerberos_url? is true' do
      let(:gitlab_kerberos_url) { Gitlab.config.build_gitlab_kerberos_url }
      let(:repo_kerberos_url) { "#{gitlab_kerberos_url}/#{project.full_path}.git" }

      before do
        allow(helper).to receive(:alternative_kerberos_url?).and_return(true)
      end

      it { is_expected.to include(kerberos_url: repo_kerberos_url) }
    end

    context 'when alternative_kerberos_url? is false' do
      before do
        allow(helper).to receive(:alternative_kerberos_url?).and_return(false)
      end

      it { is_expected.to include(kerberos_url: '') }
    end
  end

  describe '#vue_file_list_data' do
    before do
      project.add_developer(user)
      allow(helper).to receive_messages(selected_branch: sha, current_user: user)
      sign_in(user)
    end

    it 'returns a list of attributes related to the project' do
      expect(helper.vue_file_list_data(project, sha)).to include(
        project_path: project.full_path,
        project_short_path: project.path,
        ref: sha,
        escaped_ref: sha,
        full_name: project.name_with_namespace,
        resource_id: project.to_global_id,
        user_id: user.to_global_id,
        explain_code_available: 'false',
        target_branch: sha
      )
    end
  end

  describe '#web_ide_button_data' do
    let(:organization) { build_stubbed(:organization) }

    before do
      Current.organization = organization
      allow(helper).to receive(:project_to_use).and_return(project)
      allow(helper).to receive(:project_ci_pipeline_editor_path).and_return('')
    end

    it 'includes workspace data and project id properties' do
      options = {}

      expect(helper.web_ide_button_data(options)).to include(
        new_workspace_path: new_remote_development_workspace_path,
        project_id: project.id,
        organization_id: organization.id
      )
    end
  end
end
