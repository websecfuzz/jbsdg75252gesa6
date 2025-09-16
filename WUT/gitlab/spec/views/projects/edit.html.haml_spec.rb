# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/edit' do
  include Devise::Test::ControllerHelpers
  include ProjectForksHelper

  let(:project) { create(:project) }
  let(:user) { create(:admin) }

  before do
    assign(:project, project)

    allow(controller).to receive(:current_user).and_return(user)
    allow(view).to receive_messages(
      current_user: user,
      can?: true,
      current_application_settings: Gitlab::CurrentSettings.current_application_settings
    )
  end

  context 'project export disabled' do
    it 'does not display the project export option' do
      stub_application_setting(project_export_enabled?: false)

      render

      expect(rendered).not_to have_content('Export project')
    end
  end

  context 'forking' do
    before do
      assign(:project, project)

      allow(view).to receive(:current_user).and_return(user)
    end

    context 'project is not a fork' do
      it 'hides the remove fork relationship settings' do
        render

        expect(rendered).not_to have_content('Remove fork relationship')
      end
    end

    context 'project is a fork' do
      let(:source_project) { create(:project) }
      let(:project) { fork_project(source_project) }

      it 'shows the remove fork relationship settings to an authorized user' do
        allow(view).to receive(:can?).with(user, :remove_fork_project, project).and_return(true)

        render

        expect(rendered).to have_content('Remove fork relationship')
        expect(rendered).to have_link(source_project.full_name, href: project_path(source_project))
      end

      it 'hides the fork relationship settings from an unauthorized user' do
        allow(view).to receive(:can?).with(user, :remove_fork_project, project).and_return(false)

        render

        expect(rendered).not_to have_content('Remove fork relationship')
      end

      it 'hides the fork source from an unauthorized user' do
        allow(view).to receive(:can?).with(user, :read_project, source_project).and_return(false)

        render

        expect(rendered).to have_content('Remove fork relationship')
        expect(rendered).not_to have_content(source_project.full_name)
      end

      it 'shows the fork source to an authorized user' do
        allow(view).to receive(:can?).with(user, :read_project, source_project).and_return(true)

        render

        expect(rendered).to have_content('Remove fork relationship')
        expect(rendered).to have_link(source_project.full_name, href: project_path(source_project))
      end
    end
  end

  describe 'prompt user about registration features' do
    context 'when service ping is enabled' do
      before do
        stub_application_setting(usage_ping_enabled: true)
      end

      it_behaves_like 'does not render registration features prompt', :project_disabled_repository_size_limit
    end

    context 'with no license and service ping disabled', :without_license do
      before do
        stub_application_setting(usage_ping_enabled: false)
      end

      it_behaves_like 'renders registration features prompt', :project_disabled_repository_size_limit
    end
  end

  describe 'notifications on renaming the project path' do
    context 'when the GitlabAPI is supported' do
      before do
        allow(ContainerRegistry::GitlabApiClient).to receive(:supports_gitlab_api?).and_return(true)
      end

      it 'displays the warning regarding the container registry' do
        render

        expect(rendered).to have_content('new uploads to the container registry are blocked')
      end
    end

    context 'when the GitlabAPI is not supported' do
      before do
        allow(ContainerRegistry::GitlabApiClient).to receive(:supports_gitlab_api?).and_return(false)
      end

      it 'does not display the warning regarding the container registry' do
        render

        expect(rendered).not_to have_content('new uploads to the container registry are blocked')
      end
    end
  end

  describe 'restoring a project', feature_category: :groups_and_projects do
    let_it_be(:organization) { build_stubbed(:organization) }

    context 'when project is pending deletion' do
      let_it_be(:project) do
        build_stubbed(:project, marked_for_deletion_at: Date.current, organization: organization)
      end

      it 'renders restore project card and action' do
        render

        expect(rendered).to render_template('shared/groups_projects/settings/_restore')
        expect(rendered).to have_link('Restore project')
      end
    end

    context 'when project is not pending deletion' do
      it 'does not render restore project card and action' do
        render

        expect(rendered).to render_template('shared/groups_projects/settings/_restore')
        expect(rendered).not_to have_link('Restore project')
      end
    end
  end
end
