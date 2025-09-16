# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/project', feature_category: :groups_and_projects do
  let(:user) { build_stubbed(:user) }

  before do
    assign(:project, project)
    allow(view).to receive(:current_user_mode).and_return(Gitlab::Auth::CurrentUserMode.new(user))
  end

  context 'when free plan limit alert is present' do
    let_it_be(:project) { create(:project, :in_group) }

    it 'renders the alert partial' do
      render

      expect(rendered).to render_template('projects/_free_user_cap_alert')
    end
  end

  context 'with importing alert' do
    let(:hide_importing_alert) { nil }

    let_it_be(:project) do
      create(:project, import_type: 'gitlab_project', import_state: create(:import_state, :started))
    end

    subject(:rendered_alert) { view.content_for(:page_level_alert) }

    before do
      assign(:hide_importing_alert, hide_importing_alert)
      render
    end

    it 'renders the alert' do
      expect(rendered_alert).to have_text('Import in progress')

      expect(rendered_alert).to have_text(
        'This project is being imported. Do not make any changes to the project until the import is complete.'
      )
    end

    context 'when hide_importing_alert' do
      let(:hide_importing_alert) { true }

      it 'does not render the alert' do
        expect(rendered_alert).to be_nil
      end
    end
  end

  describe '_unlimited_members_during_trial_alert' do
    let(:project_namespace) { build_stubbed(:project_namespace) }
    let(:project) { build_stubbed(:project, project_namespace: project_namespace) }

    context 'when alert is hidden' do
      before do
        view.content_for(:hide_unlimited_members_during_trial_alert, true)
      end

      it 'does not render the alert' do
        render

        expect(rendered).not_to render_template('shared/_unlimited_members_during_trial_alert')
      end
    end

    context 'when alert is rendered' do
      it 'renders the alert' do
        render

        expect(rendered).to render_template('shared/_unlimited_members_during_trial_alert')
      end
    end
  end
end
