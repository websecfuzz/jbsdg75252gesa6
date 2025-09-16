# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BlobHelper, feature_category: :source_code_management do
  include TreeHelper
  include FakeBlobHelpers

  describe '#licenses_for_select' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, namespace: group) }
    let_it_be(:group_category) { "Group #{group.full_name}" }

    let(:categories) { result.keys }
    let(:by_group) { result[group_category] }
    let(:by_instance) { result['Instance'] }
    let(:by_popular) { result[:Popular] }
    let(:by_other) { result[:Other] }

    subject(:result) { helper.licenses_for_select(project) }

    before do
      stub_ee_application_setting(file_template_project: project)
      group.update_columns(file_template_project_id: project.id)
    end

    it 'returns Group licenses when enabled' do
      stub_licensed_features(custom_file_templates: false, custom_file_templates_for_namespace: true)

      expect(Gitlab::Template::CustomLicenseTemplate)
        .to receive(:all)
              .with(project)
              .and_return([OpenStruct.new(key: 'name', name: 'Name', project_id: project.id)])

      expect(categories).to contain_exactly(:Popular, :Other, group_category)
      expect(by_group).to contain_exactly({ id: 'name', name: 'Name', key: 'name', project_id: project.id })
      expect(by_popular).to be_present
      expect(by_other).to be_present
    end

    it 'returns Instance licenses when enabled' do
      stub_licensed_features(custom_file_templates: true, custom_file_templates_for_namespace: false)

      expect(Gitlab::Template::CustomLicenseTemplate)
        .to receive(:all)
        .with(project)
        .and_return([OpenStruct.new(key: 'name', name: 'Name', project_id: project.id)])

      expect(categories).to contain_exactly(:Popular, :Other, 'Instance')
      expect(by_instance).to contain_exactly({ id: 'name', name: 'Name', key: 'name', project_id: project.id })
      expect(by_popular).to be_present
      expect(by_other).to be_present
    end

    it 'returns no Group or Instance licenses when disabled' do
      stub_licensed_features(custom_file_templates: false, custom_file_templates_for_namespace: false)

      expect(categories).to contain_exactly(:Popular, :Other)
      expect(by_group).to be_nil
      expect(by_instance).to be_nil
      expect(by_popular).to be_present
      expect(by_other).to be_present
    end
  end

  describe '#vue_blob_header_app_data' do
    let(:blob) { fake_blob(path: 'file.md', size: 2.megabytes) }
    let(:project) { build_stubbed(:project) }
    let(:organization) { build_stubbed(:organization) }
    let(:ref) { 'main' }
    let(:breadcrumb_data) { { title: 'README.md', 'is-last': true } }

    it 'returns data related to blob header app' do
      Current.organization = organization
      allow(helper).to receive_messages(selected_branch: ref, current_user: nil,
        breadcrumb_data_attributes: breadcrumb_data)

      expect(helper.vue_blob_header_app_data(project, blob, ref)).to include({
        new_workspace_path: new_remote_development_workspace_path,
        organization_id: organization.id
      })
    end
  end

  describe '#vue_blob_app_data' do
    let(:blob) { fake_blob(path: 'file.md', size: 2.megabytes) }
    let(:project) { build_stubbed(:project) }
    let(:organization) { build_stubbed(:organization) }
    let(:ref) { 'main' }

    it 'returns data related to blob app' do
      allow(helper).to receive_messages(selected_branch: ref, current_user: nil)
      Current.organization = organization

      expect(helper.vue_blob_app_data(project, blob, ref)).to include({
        user_id: '',
        explain_code_available: 'false',
        new_workspace_path: new_remote_development_workspace_path,
        organization_id: organization.id
      })
    end
  end

  describe '#show_duo_workflow_action?' do
    let_it_be(:user) { build_stubbed(:user) }
    let_it_be(:project) { create(:project) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
    end

    context 'when blob name is Jenkinsfile' do
      let(:blob) { fake_blob(path: 'Jenkinsfile') }

      it 'returns true when user is present' do
        expect(helper.show_duo_workflow_action?(blob)).to be true
      end

      it 'returns false when user is not present' do
        allow(helper).to receive(:current_user).and_return(nil)
        expect(helper.show_duo_workflow_action?(blob)).to be false
      end
    end

    context 'when blob name is not Jenkinsfile' do
      let(:blob) { fake_blob(path: 'not_jenkinsfile.rb') }

      it 'returns false even when user is present' do
        expect(helper.show_duo_workflow_action?(blob)).to be false
      end
    end

    context 'when feature flag is disabled' do
      let(:blob) { fake_blob(path: 'Jenkinsfile') }

      it 'returns false' do
        stub_feature_flags(duo_workflow_in_ci: false)

        expect(helper.show_duo_workflow_action?(blob)).to be false
      end

      it 'returns false when user does not have the feature flag' do
        Feature.disable(:duo_workflow_in_ci, user)

        expect(helper.show_duo_workflow_action?(blob)).to be false
      end
    end
  end
end
