# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/settings/merge_requests/show', feature_category: :code_review_workflow do
  let(:project) { build_stubbed(:project) }
  let(:user) { build_stubbed(:admin) }

  before do
    assign(:project, project)

    allow(view).to receive(:current_user).and_return(user)
  end

  describe 'Duo Code Review' do
    before do
      allow(project.project_setting).to receive(:duo_features_enabled?).and_return(duo_enabled)
      allow(project.namespace).to receive(:has_active_add_on_purchase?).and_return(true)
    end

    context 'when Duo Code Review is enabled' do
      let(:duo_enabled) { true }

      it 'displays the setting header' do
        render

        expect(rendered).to have_content 'GitLab Duo Code Review'
      end

      it 'displays the setting form', :aggregate_failures do
        render

        expect(rendered).to have_css('input[id=project_project_setting_attributes_auto_duo_code_review_enabled]')
      end
    end

    context 'when Duo Code Review is not enabled' do
      let(:duo_enabled) { false }

      it 'does not display the setting' do
        render

        expect(rendered.to_s).not_to have_content 'GitLab Duo Code Review'
      end
    end
  end
end
