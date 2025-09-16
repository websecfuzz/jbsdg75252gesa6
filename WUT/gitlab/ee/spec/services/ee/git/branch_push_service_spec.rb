# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Git::BranchPushService, feature_category: :source_code_management do
  include RepoHelpers

  let_it_be(:user) { create(:user) }

  let(:blankrev)   { Gitlab::Git::SHA1_BLANK_SHA }
  let(:oldrev)     { sample_commit.parent_id }
  let(:newrev)     { sample_commit.id }
  let(:ref)        { 'refs/heads/master' }

  let(:params) do
    { change: { oldrev: oldrev, newrev: newrev, ref: ref } }
  end

  subject(:branch_push_service) { described_class.new(project, user, params) }

  context 'with pull project' do
    let_it_be_with_reload(:project) { create(:project, :repository, :mirror) }

    before do
      allow(project.repository).to receive(:commit).and_call_original
      allow(project.repository).to receive(:commit).with("master").and_return(nil)
    end

    context 'with ElasticSearch indexing', :elastic, :clean_gitlab_redis_shared_state,
      feature_category: :global_search do
      before do
        stub_ee_application_setting(elasticsearch_indexing?: true)
      end

      it 'runs Search::Elastic::CommitIndexerWorker' do
        expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_async).with(project.id)

        branch_push_service.execute
      end

      it "triggers indexer when push to default branch", :sidekiq_might_not_need_inline do
        expect_next_instance_of(Gitlab::Elastic::Indexer) do |instance|
          expect(instance).to receive(:run)
        end

        branch_push_service.execute
      end

      context 'when push to non-default branch' do
        let(:ref) { 'refs/heads/other' }

        it 'does not trigger indexer when push to non-default branch' do
          expect_any_instance_of(Gitlab::Elastic::Indexer).not_to receive(:run)

          branch_push_service.execute
        end
      end

      context 'when limited indexing is on' do
        before do
          stub_ee_application_setting(elasticsearch_limit_indexing: true)
        end

        context 'when the project is not enabled specifically' do
          it 'does not run Search::Elastic::CommitIndexerWorker' do
            expect(Search::Elastic::CommitIndexerWorker).not_to receive(:perform_async)

            branch_push_service.execute
          end
        end

        context 'when a project is enabled specifically' do
          before do
            create :elasticsearch_indexed_project, project: project
          end

          it 'runs Search::Elastic::CommitIndexerWorker' do
            expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_async).with(project.id)

            branch_push_service.execute
          end
        end

        context 'when a group is enabled' do
          let(:group) { create(:group) }
          let(:project) { create(:project, :repository, :mirror, group: group) }

          before do
            create :elasticsearch_indexed_namespace, namespace: group
          end

          it 'runs Search::Elastic::CommitIndexerWorker' do
            expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_async).with(project.id)

            branch_push_service.execute
          end
        end
      end
    end

    context 'with Zoekt indexing', :zoekt_settings_enabled, feature_category: :global_search do
      let(:use_zoekt) { true }

      before do
        allow(project).to receive(:use_zoekt?).and_return(use_zoekt)
      end

      it 'triggers async_update_zoekt_index' do
        expect(project.repository).to receive(:async_update_zoekt_index)

        branch_push_service.execute
      end

      context 'when pushing to a non-default branch' do
        let(:ref) { 'refs/heads/other' }

        it 'does not trigger async_update_zoekt_index' do
          expect(project.repository).not_to receive(:async_update_zoekt_index)

          branch_push_service.execute
        end
      end

      context 'when application_setting zoekt_indexing_enabled is disabled' do
        before do
          stub_ee_application_setting(zoekt_indexing_enabled: false)
        end

        it 'does not trigger async_update_zoekt_index' do
          expect(project.repository).not_to receive(:async_update_zoekt_index)

          branch_push_service.execute
        end
      end

      context 'when zoekt is not enabled for the project' do
        let(:use_zoekt) { false }

        it 'does not trigger async_update_zoekt_index' do
          expect(project.repository).not_to receive(:async_update_zoekt_index)

          branch_push_service.execute
        end
      end
    end

    context 'with knowledge graph indexing', feature_category: :knowledge_graph do
      let(:use_duo) { [:addon] }

      before do
        allow(GitlabSubscriptions::AddOnPurchase).to receive(:for_active_add_ons).and_return(use_duo)
      end

      it 'schedules IndexingTaskWorker' do
        expect(::Ai::KnowledgeGraph::IndexingTaskWorker)
          .to receive(:perform_async).with(project.project_namespace.id, :index_graph_repo)

        branch_push_service.execute
      end

      context 'when pushing to a non-default branch' do
        let(:ref) { 'refs/heads/other' }

        it 'does not schedule IndexingTaskWorker' do
          expect(::Ai::KnowledgeGraph::IndexingTaskWorker)
            .not_to receive(:perform_async).with(project.project_namespace.id, :index_graph_repo)

          branch_push_service.execute
        end
      end

      context 'when zoekt_indexing_enabled flag is disabled' do
        before do
          stub_feature_flags(knowledge_graph_indexing: false)
        end

        it 'does not schedule IndexingTaskWorker' do
          expect(::Ai::KnowledgeGraph::IndexingTaskWorker)
            .not_to receive(:perform_async).with(project.project_namespace.id, :index_graph_repo)

          branch_push_service.execute
        end
      end

      context 'when duo features are not enabled for the project' do
        let(:use_duo) { [] }

        it 'does not schedule IndexingTaskWorker' do
          expect(::Ai::KnowledgeGraph::IndexingTaskWorker)
            .not_to receive(:perform_async).with(project.project_namespace.id, :index_graph_repo)

          branch_push_service.execute
        end
      end
    end

    context 'with external pull requests' do
      it 'runs UpdateExternalPullRequestsWorker' do
        expect(UpdateExternalPullRequestsWorker).to receive(:perform_async).with(project.id, user.id, ref)

        branch_push_service.execute
      end

      context 'when project is not mirror' do
        before do
          allow(project).to receive(:mirror?).and_return(false)
        end

        it 'does nothing' do
          expect(UpdateExternalPullRequestsWorker).not_to receive(:perform_async)

          branch_push_service.execute
        end
      end

      context 'when param skips pipeline creation' do
        before do
          params[:create_pipelines] = false
        end

        it 'does nothing' do
          expect(UpdateExternalPullRequestsWorker).not_to receive(:perform_async)

          branch_push_service.execute
        end
      end
    end

    context 'for Product Analytics' do
      using RSpec::Parameterized::TableSyntax

      let(:group) { create(:group) }

      where(:feature_flag_enabled, :default_branch, :licence_available, :called) do
        true  | 'master' | true  | true
        true  | 'master' | false | false
        true  | 'other'  | true  | false
        true  | 'other'  | false | false
        false | 'master' | true  | false
        false | 'master' | false | false
        false | 'other'  | true  | false
        false | 'other'  | false | false
      end

      before do
        allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
        project.update!(group: group)
        project.group.root_ancestor.namespace_settings.update!(
          experiment_features_enabled: true,
          product_analytics_enabled: true
        )
        stub_licensed_features(product_analytics: licence_available)
        stub_feature_flags(product_analytics_features: feature_flag_enabled)
        allow(project).to receive(:default_branch).and_return(default_branch)
      end

      with_them do
        it 'enqueues the worker if appropriate' do
          if called
            expect(::ProductAnalytics::PostPushWorker).to receive(:perform_async).once
          else
            expect(::ProductAnalytics::PostPushWorker).not_to receive(:perform_async)
          end

          branch_push_service.execute
        end
      end
    end

    describe 'Repository X-Ray dependency scanning', feature_category: :code_suggestions do
      before do
        project.update!(duo_features_enabled: true)
      end

      shared_examples 'does not enqueue the X-Ray worker' do
        it 'does not schedule a dependency scan' do
          expect(Ai::RepositoryXray::ScanDependenciesWorker).not_to receive(:perform_async)

          branch_push_service.execute
        end
      end

      context 'when pushing to the default branch' do
        it 'enqueues the X-Ray worker' do
          expect(Ai::RepositoryXray::ScanDependenciesWorker).to receive(:perform_async).with(project.id)

          branch_push_service.execute
        end

        context 'when the project does not have Duo features enabled' do
          before do
            project.update!(duo_features_enabled: false)
          end

          it_behaves_like 'does not enqueue the X-Ray worker'
        end
      end

      context 'when pushing to a non-default branch' do
        let(:ref) { 'refs/heads/other' }

        it_behaves_like 'does not enqueue the X-Ray worker'
      end

      context 'when removing a branch' do
        let(:newrev) { Gitlab::Git::SHA1_BLANK_SHA }

        it_behaves_like 'does not enqueue the X-Ray worker'
      end
    end

    describe 'Pipeline execution policy metadata sync' do
      let(:feature_licensed) { true }

      before do
        stub_licensed_features(security_orchestration_policies: feature_licensed)
      end

      context 'without any security_pipeline_execution_policy_config_link' do
        it 'does not run the worker' do
          expect(Security::SyncLinkedPipelineExecutionPolicyConfigsWorker).not_to receive(:perform_async)
        end
      end

      context 'with security_pipeline_execution_policy_config_link' do
        before do
          create(:security_pipeline_execution_policy_config_link, project: project)
        end

        it 'runs a worker' do
          expect(Security::SyncLinkedPipelineExecutionPolicyConfigsWorker)
            .to receive(:perform_async)
                  .with(project.id, user.id, oldrev, newrev, ref)
                  .ordered

          branch_push_service.execute
        end

        context 'when feature is not licensed' do
          let(:feature_licensed) { false }

          it 'does not run the worker' do
            expect(Security::SyncLinkedPipelineExecutionPolicyConfigsWorker).not_to receive(:perform_async)
          end
        end
      end
    end
  end
end
