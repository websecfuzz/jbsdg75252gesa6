# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'compliance_management/compliance_framework/_compliance_framework_info.html.haml', feature_category: :compliance_management do
  let(:framework1) { build_stubbed(:compliance_framework) }
  let(:project) do
    build_stubbed(:project,
      compliance_framework_settings:
      [build_stubbed(:compliance_framework_project_setting, compliance_management_framework: framework1)])
  end

  before do
    allow(view).to receive(:show_compliance_frameworks_info?).with(project).and_return(show_compliance_frameworks_info)
    allow(view).to receive(:can?).with(anything, :read_compliance_adherence_report,
      project).and_return(can_view_dashboard)
  end

  context 'when compliance frameworks info is enabled and user has permissions' do
    let(:show_compliance_frameworks_info) { true }
    let(:can_view_dashboard) { true }

    it 'renders the #js-compliance-info element with correct data' do
      render('compliance_management/compliance_framework/compliance_frameworks_info', project: project)
      expect(rendered).to have_selector('#js-compliance-info')
      expect(rendered).to have_selector("[data-project-path='#{project.full_path}']")
      expect(rendered).to have_selector("[data-compliance-center-path='#{compliance_center_path(project)}']")
      expect(rendered).to have_selector("[data-can-view-dashboard]")
    end
  end

  context 'when compliance frameworks info is enabled but user do not have permissions' do
    let(:show_compliance_frameworks_info) { true }
    let(:can_view_dashboard) { false }

    it 'renders the #js-compliance-info element with correct data' do
      render('compliance_management/compliance_framework/compliance_frameworks_info', project: project)
      expect(rendered).to have_selector('#js-compliance-info')
      expect(rendered).to have_selector("[data-project-path='#{project.full_path}']")
      expect(rendered).to have_selector("[data-compliance-center-path='#{compliance_center_path(project)}']")
      expect(rendered).not_to have_selector("[data-can-view-dashboard]")
    end
  end

  context 'when compliance frameworks info is disabled' do
    let(:show_compliance_frameworks_info) { false }
    let(:can_view_dashboard) { true }

    it 'does not render the #js-compliance-info element' do
      render('compliance_management/compliance_framework/compliance_frameworks_info', project: project)

      expect(rendered).not_to have_selector('#js-compliance-info')
    end
  end

  context 'when compliance frameworks info is enabled but no frameworks exist' do
    let(:show_compliance_frameworks_info) { true }
    let(:can_view_dashboard) { true }

    before do
      allow(project).to receive(:compliance_framework_settings).and_return([])
    end

    it 'does not render any compliance frameworks info' do
      render('compliance_management/compliance_framework/compliance_frameworks_info', project: project)

      expect(rendered).not_to have_selector('[data-testid="compliance-frameworks-info"]')
    end
  end
end
