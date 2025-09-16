# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/edit' do
  let_it_be(:organization) { create(:organization) }
  let(:project) { create(:project, organization: organization) }
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

  describe 'prompt user about registration features' do
    context 'with no license and service ping disabled' do
      before do
        allow(License).to receive(:current).and_return(nil)
        stub_application_setting(usage_ping_enabled: false)
      end

      it_behaves_like 'renders registration features prompt', :project_disabled_repository_size_limit
      it_behaves_like 'renders registration features settings link'
    end

    context 'with a valid license and service ping disabled' do
      before do
        license = build(:license)
        allow(License).to receive(:current).and_return(license)
        stub_application_setting(usage_ping_enabled: false)
      end

      it_behaves_like 'does not render registration features prompt', :project_disabled_repository_size_limit
    end
  end

  context 'when rendering for a user that is not an owner', feature_category: :permissions do
    let_it_be(:user) { create(:user) }

    let(:can_archive_projects) { false }
    let(:can_remove_projects) { false }

    before do
      allow(view).to receive(:can?).with(user, :archive_project, project).and_return(can_archive_projects)
      allow(view).to receive(:can?).with(user, :remove_project, project).and_return(can_remove_projects)
      render
    end

    subject { rendered }

    it { is_expected.not_to have_link(_('Archive project')) }
    it { is_expected.not_to have_text(_('Delete project')) }

    context 'when the user can archive projects' do
      let(:can_archive_projects) { true }

      it { is_expected.to have_link(_('Archive project')) }
    end

    context 'when the user can remove projects' do
      let(:can_remove_projects) { true }

      it { is_expected.to have_text(_('Delete project')) }
    end
  end
end
