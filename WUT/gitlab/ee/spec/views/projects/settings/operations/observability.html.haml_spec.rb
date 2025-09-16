# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/settings/operations/_observability.html.haml', feature_category: :observability do
  let_it_be(:setting) { build(:project_setting) }

  let_it_be(:project) { build(:project, project_setting: setting) }
  let_it_be(:user) { build_stubbed(:user, maintainer_of: project) }

  before do
    assign :project, project
    allow(view).to receive(:current_user).and_return(user)

    allow(Ability).to receive(:allowed?).with(user, :read_observability, project).and_return(true)
  end

  describe 'Operations > Tracing, Metrics & Logs' do
    context 'when licensed' do
      it 'renders the Observability Settings page' do
        render

        expect(rendered).to have_content _('Tracing, Metrics & Logs')
        expect(rendered).to have_css('input[id=project_observability_alerts_enabled]')
      end
    end

    context 'when not licensed' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :read_observability, project).and_return(false)
      end

      it 'does not renders the Observability settings page' do
        render_if_exists

        expect(rendered).not_to have_content _('Tracing, Metrics & Logs')
      end
    end
  end
end
