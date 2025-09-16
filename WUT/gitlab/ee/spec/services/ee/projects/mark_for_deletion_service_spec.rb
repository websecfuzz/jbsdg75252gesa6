# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::MarkForDeletionService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be_with_reload(:project) do
    create(:project, :repository, namespace: user.namespace)
  end

  subject(:result) { described_class.new(project, user).execute }

  it 'does not hide the project', :aggregate_failures do
    expect(result[:status]).to eq(:success)
    expect(project).to be_self_deletion_scheduled
    expect(project).not_to be_hidden
  end

  context 'when the project is already marked for deletion' do
    let(:marked_for_deletion_at) { 2.days.ago }

    it 'does not change original date', :freeze_time, :aggregate_failures do
      project.update!(marked_for_deletion_at: marked_for_deletion_at)

      expect(result[:status]).to eq(:success)
      expect(project.marked_for_deletion_at).to eq(marked_for_deletion_at.to_date)
    end
  end

  context 'when attempting to mark security policy project for deletion' do
    before do
      stub_licensed_features(security_orchestration_policies: true)
      create(:security_orchestration_policy_configuration, security_policy_management_project: project)
    end

    it 'errors' do
      expect(result).to eq(
        status: :error,
        message: 'Project cannot be deleted because it is linked as a security policy project')
    end

    it "doesn't mark the project for deletion" do
      expect { result }.not_to change { project.self_deletion_scheduled? }.from(false)
    end

    context 'without licensed feature' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'marks the project for deletion' do
        expect { result }.to change { project.self_deletion_scheduled? }.from(false).to(true)
      end
    end
  end

  context 'for audit events' do
    it 'saves audit event' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'project_path_updated')
      ).and_call_original

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'project_name_updated')
      ).and_call_original

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'project_deletion_marked')
      ).and_call_original

      expect { result }.to change { AuditEvent.count }.by(3)
    end
  end
end
