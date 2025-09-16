# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::UpdateDefaultFrameworkWorker, feature_category: :compliance_management do
  let_it_be(:worker) { described_class.new }
  let_it_be(:user) { create(:user) }
  let_it_be(:admin_bot) { create(:user, :admin_bot, :admin) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group, name: 'GDPR') }

  let(:job_args) { [user.id, project.id, framework.id] }

  shared_examples 'updates the compliance framework for the project' do
    it do
      expect(project.compliance_management_frameworks).to eq([])

      worker.perform(*job_args)

      expect(project.reload.compliance_management_frameworks).to eq([framework])
    end
  end

  describe "#perform" do
    before do
      group.add_developer(user)
      stub_licensed_features(custom_compliance_frameworks: true, compliance_framework: true)
    end

    it 'invokes ComplianceManagement::Frameworks::UpdateProjectService' do
      params = [project, admin_bot, [framework]]

      expect_next_instance_of(ComplianceManagement::Frameworks::UpdateProjectService, *params) do |assign_service|
        expect(assign_service).to receive(:execute).and_call_original
      end

      worker.perform(*job_args)
    end

    context 'when admin mode is not enabled', :do_not_mock_admin_mode_setting do
      include_examples 'updates the compliance framework for the project'
    end

    context 'when admin mode is enabled', :request_store do
      before do
        stub_application_setting(admin_mode: true)
      end

      include_examples 'updates the compliance framework for the project'
    end

    it_behaves_like 'an idempotent worker'

    it 'rescues and logs the exception if project does not exist' do
      expect(Gitlab::ErrorTracking).to receive(:log_exception).with(instance_of(ActiveRecord::RecordNotFound))

      worker.perform(user.id, non_existing_record_id, framework.id)
    end
  end
end
