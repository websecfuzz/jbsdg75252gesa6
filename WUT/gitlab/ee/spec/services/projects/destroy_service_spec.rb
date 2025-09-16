# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::DestroyService, feature_category: :groups_and_projects do
  include EE::GeoHelpers
  include BatchDestroyDependentAssociationsHelper

  let!(:user) { create(:user) }
  let!(:project) { create(:project, :repository, namespace: user.namespace) }
  let!(:project_id) { project.id }
  let!(:project_name) { project.name }
  let!(:project_path) { project.disk_path }
  let!(:wiki_path) { project.wiki.disk_path }
  let!(:storage_name) { project.repository_storage }

  subject(:project_destroy_service) { described_class.new(project, user, {}) }

  before do
    stub_container_registry_config(enabled: true)
    stub_container_registry_tags(repository: :any, tags: [])
  end

  context 'when project is a mirror' do
    let(:max_capacity) { Gitlab::CurrentSettings.mirror_max_capacity }
    let_it_be(:project_mirror) { create(:project, :mirror, :repository, :import_scheduled) }

    let(:result) { described_class.new(project_mirror, project_mirror.first_owner, {}).execute }

    before do
      Gitlab::Mirror.increment_capacity(project_mirror.id)
    end

    it 'decrements capacity if mirror was scheduled' do
      expect { result }.to change { Gitlab::Mirror.available_capacity }.from(max_capacity - 1).to(max_capacity)
    end
  end

  context 'when running on a primary node' do
    let_it_be(:primary) { create(:geo_node, :primary) }
    let_it_be(:secondary) { create(:geo_node) }

    before do
      stub_current_geo_node(primary)
    end

    it 'calls replicator to update Geo', :aggregate_failures do
      # Run Sidekiq immediately to check that renamed repository will be removed
      Sidekiq::Testing.inline! do
        expect(project_destroy_service).to receive(:log_destroy_events).and_call_original
        expect(project).to receive(:geo_handle_after_destroy)

        project_destroy_service.execute
      end
    end

    it 'does not call replicator to update Geo if project deletion fails' do
      allow(project).to receive(:destroy!).and_raise(StandardError.new('Other error message'))

      Sidekiq::Testing.inline! do
        expect(project_destroy_service).to receive(:log_destroy_event).and_call_original
        expect_next_instance_of(Geo::ProjectRepositoryReplicator).never

        project_destroy_service.execute
      end
    end

    context 'when wiki_repository does not exist' do
      it 'does not call replicator to update Geo', :aggregate_failures do
        # Run Sidekiq immediately to check that renamed repository will be removed
        Sidekiq::Testing.inline! do
          expect(project_destroy_service).to receive(:log_destroy_events).and_call_original
          expect_next_instance_of(Geo::ProjectWikiRepositoryReplicator).never

          project_destroy_service.execute
        end
      end
    end

    context 'when wiki_repository exists' do
      before do
        create(:project_wiki_repository, project: project)
      end

      it 'calls replicator to update Geo', :aggregate_failures do
        # Run Sidekiq immediately to check that renamed repository will be removed
        Sidekiq::Testing.inline! do
          expect(project_destroy_service).to receive(:log_destroy_events).and_call_original
          expect(project.wiki_repository.replicator).to receive(:geo_handle_after_destroy)

          project_destroy_service.execute
        end
      end

      it 'does not call replicator to update Geo if project deletion fails' do
        allow(project).to receive(:destroy!).and_raise(StandardError.new('Other error message'))

        Sidekiq::Testing.inline! do
          expect(project_destroy_service).to receive(:log_destroy_event).and_call_original
          expect_next_instance_of(Geo::ProjectWikiRepositoryReplicator).never

          project_destroy_service.execute
        end
      end

      it 'logs an event to the Geo event log' do
        Sidekiq::Testing.inline! do
          expect(project_destroy_service).to receive(:log_destroy_events).and_call_original
          expect { project_destroy_service.execute }.to change {
            Geo::Event.where(replicable_name: :project_wiki_repository, event_name: :deleted).count
          }.by(1)

          payload = Geo::Event.where(replicable_name: :project_wiki_repository, event_name: :deleted).last.payload

          expect(payload['model_record_id']).to eq(project.wiki_repository.id)
          expect(payload['disk_path']).to eq(project.wiki_repository.repository.disk_path)
          expect(payload['full_path']).to eq(project.wiki_repository.repository.full_path)
          expect(payload['repository_storage']).to eq(project.wiki_repository.repository_storage)
        end
      end

      it 'does not log an event to the Geo event log if feature flag disabled' do
        stub_feature_flags(geo_project_wiki_repository_replication: false)

        Sidekiq::Testing.inline! do
          expect(project_destroy_service).to receive(:log_destroy_events).and_call_original
          expect { project_destroy_service.execute }.not_to change {
            Geo::Event.where(replicable_name: :project_wiki_repository, event_name: :deleted).count
          }
        end
      end
    end

    context 'with a design management repository' do
      before do
        project.create_design_management_repository
      end

      it 'calls replicator to update Geo', :sidekiq_inline do
        # Run Sidekiq immediately to check that renamed repository will be removed
        Sidekiq::Testing.inline! do
          expect(project_destroy_service).to receive(:log_destroy_events).and_call_original
          expect(project.design_management_repository.replicator).to receive(:geo_handle_after_destroy)

          project_destroy_service.execute
        end
      end

      it 'does not call replicator to update Geo if project deletion fails', :aggregate_failures do
        allow(project).to receive(:destroy!).and_raise(StandardError.new('Other error message'))

        Sidekiq::Testing.inline! do
          expect(project_destroy_service).to receive(:log_destroy_event).and_call_original
          expect_next_instance_of(Geo::DesignManagementRepositoryReplicator).never

          project_destroy_service.execute
        end
      end

      it 'logs an event to the Geo event log' do
        # Run Sidekiq immediately to check that renamed repository will be removed
        Sidekiq::Testing.inline! do
          expect(project_destroy_service).to receive(:log_destroy_events).and_call_original
          expect { project_destroy_service.execute }.to change {
            Geo::Event.where(replicable_name: :design_management_repository, event_name: :deleted).count
          }.by(1)

          payload = Geo::Event.where(replicable_name: :design_management_repository, event_name: :deleted).last.payload

          expect(payload['model_record_id']).to eq(project.design_management_repository.id)
          expect(payload['disk_path']).to eq(project.design_management_repository.disk_path)
          expect(payload['full_path']).to eq(project.design_management_repository.full_path)
          expect(payload['repository_storage']).to eq(project.design_management_repository.repository_storage)
        end
      end
    end
  end

  context 'when project deletion triggers group webhooks' do
    let_it_be(:group, reload: true) { create(:group) }
    let(:project) { create(:project, :repository, namespace_id: group.id) }

    before do
      stub_licensed_features(group_webhooks: true)
      group.add_owner(user)
    end

    context 'with no active group hooks configured' do
      it 'does not call the hooks' do
        expect(WebHookService).not_to receive(:new)

        project_destroy_service.execute
      end
    end

    context 'with active group hooks configured' do
      let!(:hook) { create(:group_hook, group: group, project_events: true) }
      let(:hook_data) { { mock_data: true } }

      before do
        allow_next_instance_of(::Gitlab::HookData::ProjectBuilder) do |builder|
          allow(builder).to receive(:build).and_return(hook_data)
        end
      end

      it 'calls the hooks' do
        expect_next_instance_of(WebHookService, hook, hook_data, 'project_hooks', anything) do |service|
          expect(service).to receive(:async_execute)
        end

        project_destroy_service.execute
      end
    end
  end

  context 'audit events' do
    context 'when the project belongs to a user namespace' do
      include_examples 'audit event logging' do
        let(:operation) { project_destroy_service.execute }

        let(:fail_condition!) do
          expect(project).to receive(:destroy!).and_raise(StandardError.new('Other error message'))
        end

        let(:event_type) { 'project_destroyed' }

        let(:attributes) do
          {
            author_id: user.id,
            entity_id: 1,
            entity_type: "Gitlab::Audit::InstanceScope",
            details: {
              remove: 'project',
              author_name: user.name,
              event_name: 'project_destroyed',
              target_id: project.id,
              target_type: 'Project',
              target_details: project.full_path,
              author_class: user.class.name,
              custom_message: 'Project destroyed'
            }
          }
        end
      end
    end

    context 'when the project belongs to a group' do
      let(:group) { create :group }
      let(:project) { create :project, namespace: group }

      before do
        group.add_owner(user)
      end

      include_examples 'audit event logging' do
        let(:operation) { project_destroy_service.execute }

        let(:fail_condition!) do
          expect(project).to receive(:destroy!).and_raise(StandardError.new('Other error message'))
        end

        let(:event_type) { 'project_destroyed' }

        let(:attributes) do
          {
            author_id: user.id,
            entity_id: group.id,
            entity_type: 'Group',
            details: {
              remove: 'project',
              author_name: user.name,
              event_name: 'project_destroyed',
              target_id: project.id,
              target_type: 'Project',
              target_details: project.full_path,
              author_class: user.class.name,
              custom_message: 'Project destroyed'
            }
          }
        end
      end
    end
  end

  context 'streaming audit event' do
    let(:group) { create :group }
    let(:project) { create :project, namespace: group }

    before do
      group.add_owner(user)
      stub_licensed_features(external_audit_events: true)
      group.external_audit_event_destinations.create!(destination_url: 'http://example.com')
    end

    it 'sends the audit streaming event with json format' do
      expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
        'project_destroyed',
        nil,
        a_string_including("root_group_entity_id\":#{group.id}"))

      project_destroy_service.execute
    end
  end

  context 'system hooks exception' do
    before do
      allow_any_instance_of(SystemHooksService).to receive(:execute_hooks_for).and_raise('something went wrong')
      stub_licensed_features(extended_audit_events: true)
    end

    it 'logs an audit event' do
      expect(project_destroy_service).to receive(:log_destroy_event).and_call_original
      expect { project_destroy_service.execute }.to change(AuditEvent, :count)
    end
  end

  context 'when project has an associated ProjectNamespace' do
    let!(:project_namespace) { project.project_namespace }

    it 'destroys the associated ProjectNamespace also' do
      project_destroy_service.execute

      expect { project_namespace.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { project.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when project issues are associated with some epics' do
    let!(:group) { create(:group) }
    let!(:project) { create(:project, group: group) }
    let!(:issue1) { create(:issue, project: project) }
    let!(:issue2) { create(:issue, project: project) }
    let!(:issue3) { create(:issue, project: project) }
    let!(:epic1) { create(:epic, group: group) }
    let!(:epic2) { create(:epic, group: group) }
    let!(:epic3) { create(:epic, group: group) }
    let!(:epic_issue1) { create(:epic_issue, issue: issue1, epic: epic1) }
    let!(:epic_issue2) { create(:epic_issue, issue: issue2, epic: epic2) }
    let!(:epic_issue3) { create(:epic_issue, issue: issue3, epic: epic3) }

    before do
      group.add_owner(user)
    end

    it 'schedules cache update for associated epics in batches' do
      stub_const('::Epics::UpdateCachedMetadataWorker::BATCH_SIZE', 2)

      expect(::Epics::UpdateCachedMetadataWorker).to receive(:bulk_perform_in) do |delay, ids|
        expect(delay).to eq(1.minute)
        expect(ids.map(&:first).map(&:length)).to eq([2, 1])
        expect(ids.flatten).to match_array([epic_issue1.epic_id, epic_issue2.epic_id, epic_issue3.epic_id])
      end.once

      project_destroy_service.execute
    end
  end

  context 'when project has associated project access tokens' do
    let_it_be(:bot) { create(:user, :project_bot) }
    let_it_be(:token) { create(:personal_access_token, user: bot) }

    before do
      project.add_maintainer(bot)
    end

    it 'creates a ghost user migration entry and deletes user on execution' do
      expect { project_destroy_service.execute }.to change {
        Users::GhostUserMigration.count
      }.by(1)
    end
  end

  context 'associations destroyed in batches' do
    let!(:vulnerability) { create(:vulnerability, :with_findings, project: project) }
    let!(:finding) do
      create(:vulnerabilities_finding, vulnerability: vulnerability, project: project)
    end

    it 'destroys the associations marked as `dependent: :destroy`, in batches' do
      query_recorder = ActiveRecord::QueryRecorder.new do
        project_destroy_service.execute
      end

      expect(project.vulnerabilities).to be_empty
      expect(project.vulnerability_findings).to be_empty

      expected_queries = [
        delete_in_batches_regexps(:vulnerabilities, :project_id, project, [vulnerability]),
        delete_in_batches_regexps(:vulnerability_occurrences, :project_id, project, [finding])
      ].flatten

      expect(query_recorder.log).to include(*expected_queries)
    end
  end

  context 'when project has associated compliance requirement statuses' do
    let!(:group) { create(:group) }
    let!(:project) { create(:project, group: group) }
    let!(:framework) { create(:compliance_framework, namespace: group) }

    before do
      group.add_owner(user)

      create(:project_requirement_compliance_status, project: project,
        compliance_requirement: create(:compliance_requirement, namespace: group, framework: framework,
          name: 'requirement1')
      )
      create(:project_requirement_compliance_status, project: project,
        compliance_requirement: create(:compliance_requirement, namespace: group, framework: framework,
          name: 'requirement2')
      )
    end

    it 'destroys all associated Compliance Requirement statuses and the project', :aggregate_failures do
      expect do
        project_destroy_service.execute
      end.to change(
        ::ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus, :count).by(-2)
      .and change(Project.where(id: project.id), :count).by(-1)
    end
  end

  describe 'tag protection rules handling' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_refind(:project) { create(:project, :repository, namespace: user.namespace) }

    subject { project_destroy_service.execute }

    context 'when there are immutable tag protection rules' do
      before_all do
        create(:container_registry_protection_tag_rule,
          :immutable,
          project: project,
          tag_name_pattern: 'immutable'
        )

        project.add_owner(user)
        project.container_repositories << create(:container_repository)
      end

      context 'when there are registry tags' do
        before do
          stub_container_registry_tags(repository: project.full_path, tags: ['tag'])
          allow_any_instance_of(described_class)
            .to receive(:remove_legacy_registry_tags).and_return(true)
        end

        context 'when the licensed feature is enabled' do
          before do
            stub_licensed_features(container_registry_immutable_tag_rules: true)
          end

          it { is_expected.to be false }

          context 'when the current user is an admin', :enable_admin_mode do
            let(:user) { build_stubbed(:admin) }

            it { is_expected.to be false }
          end
        end

        context 'when the licensed feature is disabled' do
          before do
            stub_licensed_features(container_registry_immutable_tag_rules: false)
          end

          it { is_expected.to be true }

          context 'when the current user is an admin', :enable_admin_mode do
            let(:user) { build_stubbed(:admin) }

            it { is_expected.to be true }
          end
        end
      end

      context 'when there are no registry tags' do
        it { is_expected.to be true }
      end
    end
  end
end
