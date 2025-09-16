# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GitlabProjectsImportService, feature_category: :source_code_management do
  let_it_be(:namespace) { create(:namespace) }

  let(:path) { 'test-path' }
  let(:custom_template) { create(:project) }
  let(:overwrite) { false }
  let(:import_params) do
    { namespace_id: namespace.id, path: path, custom_template: custom_template, overwrite: overwrite }
  end

  subject(:service) do
    described_class.new(namespace.owner, import_params, import_type: 'gitlab_custom_project_template')
  end

  after do
    TestEnv.clean_test_path
  end

  describe '#execute' do
    context 'when template export job is created' do
      it 'if project saved and custom template exists' do
        expect(custom_template).to receive(:add_template_export_job)

        project = service.execute

        expect(project.saved?).to be true
      end

      it 'sets custom template import strategy after export' do
        expect(custom_template)
          .to receive(:add_template_export_job).with(
            current_user: namespace.owner,
            after_export_strategy: instance_of(Import::AfterExportStrategies::CustomTemplateExportImportStrategy)
          )

        service.execute
      end
    end

    context 'when template export job is not created' do
      it 'if project not saved' do
        allow_next_instance_of(Project) do |instance|
          allow(instance).to receive(:saved?).and_return(false)
        end

        expect(custom_template).not_to receive(:add_template_export_job)

        project = service.execute

        expect(project.saved?).to be false
      end
    end

    it_behaves_like 'gitlab projects import validations', import_type: 'gitlab_custom_project_template'
  end
end
