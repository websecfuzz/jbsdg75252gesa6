# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::RakeTaskExecutorService, :elastic_helpers, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger) }

  before do
    allow(logger).to receive(:info)
  end

  describe '#execute' do
    it 'raises an exception when unknown task is provided' do
      expect { service.execute(:foo) }.to raise_error(ArgumentError)
    end

    it 'raises an exception when the task is not implemented' do
      stub_const('::Search::RakeTaskExecutorService::TASKS', [:foo])

      expect { service.execute(:foo) }.to raise_error(NotImplementedError)
    end

    described_class::TASKS.each do |task|
      it "executes #{task} task" do
        expect(service).to receive(task).and_return(true)

        service.execute(task)
      end
    end
  end

  describe '#create_empty_index' do
    before do
      es_helper.delete_index
      es_helper.delete_standalone_indices
      es_helper.delete_migrations_index
    end

    it 'creates the default index' do
      expect { service.execute(:create_empty_index) }.to change { es_helper.index_exists? }.from(false).to(true)
    end

    context 'when SKIP_ALIAS environment variable is set' do
      before do
        stub_env('SKIP_ALIAS', '1')
      end

      after do
        es_helper.client.cat.indices(index: "#{es_helper.target_name}-*", h: 'index').split("\n").each do |index_name|
          es_helper.client.indices.delete(index: index_name)
        end
      end

      it 'does not alias the new index' do
        expect { service.execute(:create_empty_index) }
          .not_to change { es_helper.alias_exists?(name: es_helper.target_name) }
      end

      it 'does not create the migrations index if it does not exist' do
        migration_index_name = es_helper.migrations_index_name
        es_helper.delete_index(index_name: migration_index_name)

        expect { service.execute(:create_empty_index) }
          .not_to change { es_helper.index_exists?(index_name: migration_index_name) }
      end

      it 'does not create standalone indices' do
        service.execute(:create_empty_index)

        Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES.each do |class_name|
          proxy = get_class_proxy(class_name: class_name, use_separate_indices: true)

          expect(es_helper.alias_exists?(name: proxy.index_name)).to be(false), "#{proxy.index_name} shouldn't exist"
        end
      end
    end

    it 'creates the migrations index if it does not exist' do
      migration_index_name = es_helper.migrations_index_name
      es_helper.delete_index(index_name: migration_index_name)

      expect { service.execute(:create_empty_index) }
        .to change { es_helper.index_exists?(index_name: migration_index_name) }.from(false).to(true)
    end

    it 'creates standalone indices' do
      service.execute(:create_empty_index)

      Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES.each do |class_name|
        proxy = get_class_proxy(class_name: class_name, use_separate_indices: true)

        expect(es_helper.index_exists?(index_name: proxy.index_name)).to be(true), "#{proxy.index_name} shouldn't exist"
      end
    end

    it 'marks all migrations as completed' do
      expect(Elastic::DataMigrationService).to receive(:mark_all_as_completed!).and_call_original

      service.execute(:create_empty_index)
      refresh_index!

      migrations = Elastic::DataMigrationService.migrations.map(&:version)
      expect(Elastic::MigrationRecord.load_versions(completed: true)).to eq(migrations)
    end
  end

  describe '#delete_index', :elastic_clean do
    let(:helper) { ::Gitlab::Elastic::Helper.default }

    subject(:delete_index) { service.execute(:delete_index) }

    before do
      allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
    end

    it 'removes the index' do
      expect { delete_index }.to change { es_helper.index_exists? }.from(true).to(false)
    end

    context 'when delete_index returns false' do
      it 'logs that the index was not found' do
        allow(helper).to receive(:delete_index).and_return(false)

        expect(logger).to receive(:info).with(%r{Index/alias '#{helper.target_name}' was not found})

        delete_index
      end
    end

    context 'when delete_standalone_indices returns false' do
      it 'logs that the index was not found' do
        allow(helper).to receive(:delete_standalone_indices).and_return([['projects-123', 'projects', false]])

        expect(logger).to receive(:info).with(/Index 'projects-123' with alias 'projects' was not found/)

        delete_index
      end
    end

    it 'removes the migrations index' do
      expect { delete_index }.to change { es_helper.migrations_index_exists? }.from(true).to(false)
    end

    context 'when delete_migrations_index returns false' do
      it 'logs that the index was not found' do
        allow(helper).to receive(:delete_migrations_index).and_return(false)

        expect(logger).to receive(:info).with(%r{Index/alias '#{es_helper.migrations_index_name}' was not found})

        delete_index
      end
    end

    context 'when the index does not exist' do
      it 'does not error' do
        expect { service.execute(:delete_index) }.not_to raise_error
        expect { service.execute(:delete_index) }.not_to raise_error
      end
    end
  end

  describe '#index_snippets' do
    it 'indexes snippets' do
      expect(Snippet).to receive(:es_import)
      expect(logger).to receive(:info).with(/Indexing snippets/).twice

      service.execute(:index_snippets)
    end
  end

  describe '#pause_indexing' do
    let(:settings) { ::Gitlab::CurrentSettings }

    before do
      settings.update!(elasticsearch_pause_indexing: indexing_paused)
    end

    context 'when indexing is already paused' do
      let(:indexing_paused) { true }

      it 'does not do anything' do
        expect(settings).not_to receive(:update!)
        expect(logger).to receive(:info).with(/Pausing indexing.../)
        expect(logger).to receive(:info).with(/Indexing is already paused/)

        expect { service.execute(:pause_indexing) }.not_to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end

    context 'when indexing is running' do
      let(:indexing_paused) { false }

      it 'pauses indexing' do
        expect(logger).to receive(:info).with(/Pausing indexing.../)
        expect(logger).to receive(:info).with(/Indexing is now paused/)

        expect { service.execute(:pause_indexing) }.to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end
  end

  describe '#resume_indexing' do
    let(:settings) { ::Gitlab::CurrentSettings }

    before do
      settings.update!(elasticsearch_pause_indexing: indexing_paused)
    end

    context 'when indexing is already running' do
      let(:indexing_paused) { false }

      it 'does not do anything' do
        expect(logger).to receive(:info).with(/Resuming indexing.../)
        expect(logger).to receive(:info).with(/Indexing is already running/)

        expect { service.execute(:resume_indexing) }.not_to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end

    context 'when indexing is not running' do
      let(:indexing_paused) { true }

      it 'resumes indexing' do
        expect(logger).to receive(:info).with(/Resuming indexing.../)
        expect(logger).to receive(:info).with(/Indexing is now running/)

        expect { service.execute(:resume_indexing) }.to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end
  end

  describe '#estimate_cluster_size' do
    before do
      create(:namespace_root_storage_statistics, repository_size: 1.megabyte, wiki_size: 30.megabytes)
      create(:namespace_root_storage_statistics, repository_size: 10.megabytes, wiki_size: 20.megabytes)
      create(:namespace_root_storage_statistics, repository_size: 30.megabytes, wiki_size: 10.megabytes)
    end

    it 'outputs estimates' do
      expect(logger).to receive(:info).with("This GitLab instance repository size is 41 MiB and wiki size is 60 MiB.")
      expect(logger).to receive(:info)
        .with("The gitlab-test index size will be 20.5 MiB and gitlab-test-wikis index size will be 30 MiB.")
      expect(logger).to receive(:info).with("By our estimates, your cluster size will be at least 50.5 MiB.")

      service.execute(:estimate_cluster_size)
    end
  end

  describe '#estimate_shard_sizes' do
    let(:counts) { [400, 1500, 10_000_000, 50_000_000, 100_000_000, 4_000, 5_000, 5_000] }
    let(:counted_items) { described_class::CLASSES_TO_COUNT }

    before do
      allow(logger).to receive(:info)
      allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
      allow(::Gitlab::Database::Count).to receive(:approximate_counts).with(counted_items).and_return(
        Hash[counted_items.zip(counts)]
      )
    end

    it 'outputs shard size estimates' do
      expected_work_items = <<~ESTIMATE
        - gitlab-test-work_items:
          document count: 5,000
          recommended shards: 5
          recommended replicas: 1
      ESTIMATE

      expected_issues = <<~ESTIMATE
        - gitlab-test-issues:
          document count: 400
          recommended shards: 5
          recommended replicas: 1
      ESTIMATE

      expected_notes = <<~ESTIMATE.chomp
        - gitlab-test-notes:
          document count: 1,500
          recommended shards: 5
          recommended replicas: 1
      ESTIMATE

      expected_merge_requests = <<~ESTIMATE.chomp
        - gitlab-test-merge_requests:
          document count: 10,000,000
          recommended shards: 7
          recommended replicas: 1
      ESTIMATE

      expected_epics = <<~ESTIMATE.chomp
        - gitlab-test-epics:
          document count: 50,000,000
          recommended shards: 15
          recommended replicas: 1
      ESTIMATE

      expected_users = <<~ESTIMATE.chomp
        - gitlab-test-users:
          document count: 100,000,000
          recommended shards: 25
          recommended replicas: 1
      ESTIMATE

      expected_projects = <<~ESTIMATE.chomp
        - gitlab-test-projects:
          document count: 4,000
          recommended shards: 5
          recommended replicas: 1
      ESTIMATE

      expected_vulnerabilities = <<~ESTIMATE.chomp
        - gitlab-test-vulnerabilities:
          document count: 5,000
          recommended shards: 5
          recommended replicas: 1
      ESTIMATE

      expect(logger).to receive(:info).with(%r{#{expected_issues}})
      expect(logger).to receive(:info).with(/#{expected_notes}/)
      expect(logger).to receive(:info).with(/#{expected_merge_requests}/)
      expect(logger).to receive(:info).with(/#{expected_epics}/)
      expect(logger).to receive(:info).with(/#{expected_users}/)
      expect(logger).to receive(:info).with(/#{expected_projects}/)
      expect(logger).to receive(:info).with(/#{expected_work_items}/)
      expect(logger).to receive(:info).with(/#{expected_vulnerabilities}/)

      service.execute(:estimate_shard_sizes)
    end
  end

  describe '#mark_reindex_failed' do
    context 'when there is a running reindex job' do
      before do
        Search::Elastic::ReindexingTask.create!
      end

      it 'marks the current reindex job as failed' do
        expect(logger).to receive(:info).with(/Marked the current reindexing job as failed/)

        expect { service.execute(:mark_reindex_failed) }
          .to change { Search::Elastic::ReindexingTask.running? }.from(true).to(false)
      end

      it 'prints a message after marking it as failed' do
        expect(logger).to receive(:info).with(/Marked the current reindexing job as failed/)

        service.execute(:mark_reindex_failed)
      end
    end

    context 'when no running reindex job' do
      it 'just prints a message' do
        expect(logger).to receive(:info).with(/Did not find the current running reindexing job/)

        service.execute(:mark_reindex_failed)
      end
    end
  end

  describe '#list_pending_migrations' do
    let(:helper) { es_helper }

    before do
      allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:ping?).and_return(true)
    end

    context 'when there are pending migrations' do
      let(:pending_migrations) { ::Elastic::DataMigrationService.migrations.last(2) }
      let(:pending_migration1) { pending_migrations.first }
      let(:pending_migration2) { pending_migrations.second }

      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return(pending_migrations)
      end

      it 'outputs pending migrations' do
        expect(logger).to receive(:info).with(/Pending Migrations/)
        expect(logger).to receive(:info).with(/#{pending_migration1.name}/)
        expect(logger).to receive(:info).with(/#{pending_migration2.name}/)

        service.execute(:list_pending_migrations)
      end

      context 'when search service unreachable' do
        before do
          allow(helper).to receive(:ping?).and_return(false)
        end

        it 'outputs an error' do
          expect(logger).to receive(:info).with(/Pending Migrations/)
          expect(logger).to receive(:error).with(/Unable to connect to search cluster to retrieve data./)

          service.execute(:list_pending_migrations)
        end
      end
    end

    context 'when there is no pending migrations' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([])
      end

      it 'outputs message there are no pending migrations' do
        expect(logger).to receive(:info).with(/Pending Migrations/)
        expect(logger).to receive(:info).with(/There are no pending migrations./)

        service.execute(:list_pending_migrations)
      end
    end

    context 'when pending migrations are obsolete' do
      let(:obsolete_pending_migration) { ::Elastic::DataMigrationService.migrations.first }

      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([obsolete_pending_migration])
        allow(obsolete_pending_migration).to receive(:obsolete?).and_return(true)
      end

      it 'outputs that the pending migration is obsolete' do
        expect(logger).to receive(:info).with(/Pending Migrations/)
        expect(logger).to receive(:warn).with(/#{obsolete_pending_migration.name} \[Obsolete\]/)

        service.execute(:list_pending_migrations)
      end
    end
  end

  describe '#enable_search_with_elasticsearch' do
    subject(:task) { service.execute(:enable_search_with_elasticsearch) }

    let(:settings) { ::Gitlab::CurrentSettings }

    before do
      settings.update!(elasticsearch_search: es_enabled)
    end

    context 'when enabling elasticsearch with setting initially off' do
      let(:es_enabled) { false }

      it 'enables elasticsearch' do
        expect(logger).to receive(:info).with(/Setting `elasticsearch_search` has been enabled/)

        expect { task }.to change { settings.elasticsearch_search }.from(false).to(true)
      end
    end

    context 'when enabling elasticsearch with setting initially on' do
      let(:es_enabled) { true }

      it 'does nothing when elasticsearch is already enabled' do
        expect(logger).to receive(:info).with(/Setting `elasticsearch_search` was already enabled/)

        expect { task }.not_to change { settings.elasticsearch_search }
      end
    end
  end

  describe '#index_projects_status' do
    subject(:task) { service.execute(:index_projects_status) }

    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:project_no_repository) { create(:project) }
    let_it_be(:project_empty_repository) { create(:project, :empty_repo) }

    context 'when some projects missing from index' do
      before do
        create(:index_status, project: project)
      end

      it 'displays completion percentage' do
        expected = <<~STD_OUT.chomp
          Indexing is 33.33% complete (1/3 projects)
        STD_OUT

        expect(logger).to receive(:info).with(expected)

        task
      end

      context 'when elasticsearch_limit_indexing? is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_limit_indexing: true)
        end

        it 'only displays non-indexed projects that are setup for indexing' do
          create(:elasticsearch_indexed_project, project: project_no_repository)

          expected = <<~STD_OUT.chomp
            Indexing is 0.00% complete (0/1 projects)
          STD_OUT

          expect(logger).to receive(:info).with(expected)

          task
        end
      end
    end

    context 'when all projects are indexed' do
      before do
        create(:index_status, project: project)
        create(:index_status, project: project_no_repository)
        create(:index_status, project: project_empty_repository)
      end

      it 'displays that all projects are indexed' do
        expected = <<~STD_OUT.chomp
          Indexing is 100.00% complete (3/3 projects)
        STD_OUT

        expect(logger).to receive(:info).with(expected)

        task
      end

      context 'when elasticsearch_limit_indexing? is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_limit_indexing: true)
        end

        it 'only displays non-indexed projects that are setup for indexing' do
          create(:elasticsearch_indexed_project, project: project_empty_repository)

          expected = <<~STD_OUT.chomp
            Indexing is 100.00% complete (1/1 projects)
          STD_OUT

          expect(logger).to receive(:info).with(expected)

          task
        end
      end
    end
  end

  describe '#index_users' do
    let_it_be(:users) { create_list(:user, 3) }

    subject(:task) { service.execute(:index_users) }

    it 'queues jobs for all users' do
      expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!) do |*args|
        expect(args).to match_array(users)
      end
      expect(logger).to receive(:info).with(/Indexing users/).twice

      task
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { service.execute(:index_users) }

      create_list(:user, 5)

      expect { service.execute(:index_users) }.to issue_same_number_of_queries_as(control)
    end
  end

  describe '#index_namespaces' do
    let_it_be(:groups) { create_list(:group, 3) }

    subject(:task) { service.execute(:index_namespaces) }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    it 'indexes namespaces' do
      expect(ElasticNamespaceIndexerWorker).to receive(:bulk_perform_async_with_contexts)
        .with(match_array(groups), { arguments_proc: kind_of(Proc), context_proc: kind_of(Proc) })

      task
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { task }

      create_list(:group, 3)

      expect { service.execute(:index_namespaces) }.to issue_same_number_of_queries_as(control)
    end
  end

  describe '#index_projects' do
    let_it_be(:projects) { create_list(:project, 3, :in_group) }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    it 'queues jobs for each project batch' do
      expect(logger).to receive(:info).with(/Enqueuing projects/)
      expect(Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(*projects)

      service.execute(:index_projects)
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      allow(Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { service.execute(:index_projects) }

      create(:project, :in_group)
      create(:project_namespace, parent: create(:group))
      create(:project)

      expect { service.execute(:index_projects) }.to issue_same_number_of_queries_as(control)
    end

    context 'with limited indexing enabled' do
      before do
        create :elasticsearch_indexed_project, project: projects.first
        create :elasticsearch_indexed_namespace, namespace: projects.last.namespace

        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      context 'when elasticsearch_indexing is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_indexing: false)
        end

        it 'outputs a warning' do
          expect(logger).to receive(:warn).with(/WARNING: Setting `elasticsearch_indexing` is disabled/)
          expect(logger).to receive(:info).with(/Enqueuing projects/)

          service.execute(:index_projects)
        end
      end

      it 'queues jobs for all projects' do
        expect(logger).to receive(:info).with(/Enqueuing projects/)
        expect(Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(*projects)

        service.execute(:index_projects)
      end
    end
  end

  describe '#index_work_items', :elastic do
    let_it_be(:work_item) { create(:work_item) }

    it 'calls track! for work_items' do
      expect(logger).to receive(:info).with(/Indexing work_items/).twice
      expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!).with(work_item)

      service.execute(:index_work_items)
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { service.execute(:index_work_items) }

      create_list(:work_item, 3)

      expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!)

      expect { service.execute(:index_work_items) }.to issue_same_number_of_queries_as(control).or_fewer
    end

    context 'with limited indexing enabled' do
      let_it_be(:group1) { create(:group) }
      let_it_be(:group2) { create(:group) }
      let_it_be(:group3) { create(:group) }
      let_it_be(:work_item_1) { create(:work_item, namespace: group1) }
      let_it_be(:_work_item_2) { create(:work_item, namespace: group2) }
      let_it_be(:work_item_3) { create(:work_item, namespace: group3) }

      before do
        create(:elasticsearch_indexed_namespace, namespace: group1)
        create(:elasticsearch_indexed_namespace, namespace: group3)

        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      it 'does not call track! for work_items that should not be indexed' do
        expect(logger).to receive(:info).with(/Indexing work_items/).twice
        expect(Elastic::ProcessBookkeepingService).to receive(:track!) do |*work_items|
          expect(work_items).to match_array([work_item_1, work_item_3])
        end
        service.execute(:index_work_items)
      end
    end
  end

  describe '#index_epics' do
    let!(:epic) { create(:epic) }

    it 'calls maintain_indexed_namespace_associations for groups' do
      expect(logger).to receive(:info).with(/Indexing epics/).twice
      expect(Elastic::ProcessInitialBookkeepingService).to receive(:maintain_indexed_namespace_associations!)
        .with(epic.group, associations_to_index: [:epics])

      service.execute(:index_epics)
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { service.execute(:index_epics) }

      create_list(:epic, 3)

      expect(Elastic::ProcessInitialBookkeepingService).to receive(:maintain_indexed_namespace_associations!)

      expect { service.execute(:index_epics) }.to issue_same_number_of_queries_as(control)
    end

    context 'with limited indexing enabled' do
      let!(:group1) { create(:group) }
      let!(:group2) { create(:group) }
      let!(:group3) { create(:group) }

      before do
        create(:elasticsearch_indexed_namespace, namespace: group1)
        create(:elasticsearch_indexed_namespace, namespace: group3)

        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      it 'does not call maintain_indexed_namespace_associations for groups that should not be indexed' do
        expect(logger).to receive(:info).with(/Indexing epics/).twice
        expect(Elastic::ProcessBookkeepingService).to receive(:maintain_indexed_namespace_associations!) do |*params|
          expect(params.count).to eq(3)
          expect([params[0], params[1]]).to contain_exactly(group1, group3)
          expect(params[2]).to eq(associations_to_index: [:epics])
        end
        service.execute(:index_epics)
      end
    end
  end

  describe '#projects_not_indexed' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:project_no_repository) { create(:project) }
    let_it_be(:project_empty_repository) { create(:project, :empty_repo) }

    subject(:projects_not_indexed) { service.execute(:projects_not_indexed) }

    context 'when projects missing from index' do
      it 'displays non-indexed projects' do
        expect(logger).to receive(:warn)
          .with("Project '#{project.full_path}' (ID: #{project.id}) isn't indexed.")
        expect(logger).to receive(:warn)
          .with("Project '#{project_no_repository.full_path}' (ID: #{project_no_repository.id}) isn't indexed.")
        expect(logger).to receive(:warn)
          .with("Project '#{project_empty_repository.full_path}' (ID: #{project_empty_repository.id}) isn't indexed.")
        expect(logger).to receive(:info).with("3 out of 3 non-indexed projects shown.")

        projects_not_indexed
      end

      context 'when projects missing are more than MAX_PROJECTS_TO_DISPLAY' do
        before do
          stub_const("#{described_class}::MAX_PROJECTS_TO_DISPLAY", 1)
        end

        it 'displays only MAX_PROJECTS_TO_DISPLAY non-indexed projects' do
          expect(logger).to receive(:warn).with(/Project '.*' \(ID: [0-9].*\) isn't indexed/)
          expect(logger).to receive(:info).with("1 out of 3 non-indexed projects shown.")

          projects_not_indexed
        end

        context 'and SHOW_ALL env var is set to true' do
          before do
            stub_env("SHOW_ALL", true)
          end

          it 'displays all non-indexed projects' do
            expect(logger).to receive(:warn)
              .with("Project '#{project.full_path}' (ID: #{project.id}) isn't indexed.")
            expect(logger).to receive(:warn)
              .with("Project '#{project_no_repository.full_path}' (ID: #{project_no_repository.id}) isn't indexed.")
            expect(logger).to receive(:warn)
              .with("Project '#{project_empty_repository.full_path}' " \
                "(ID: #{project_empty_repository.id}) isn't indexed.")
            expect(logger).to receive(:info).with("3 out of 3 non-indexed projects shown.")

            projects_not_indexed
          end
        end
      end
    end

    context 'when all projects are indexed' do
      before do
        [project, project_no_repository, project_empty_repository].each do |p|
          create(:index_status, project: p)
        end
      end

      it 'displays that all projects are indexed' do
        expect(logger).to receive(:info).with(/All projects are currently indexed/)

        projects_not_indexed
      end
    end
  end

  describe '#index_group_wikis' do
    let(:group1) { create(:group) }
    let(:group2) { create(:group) }
    let(:group3) { create(:group) }
    let(:subgrp) { create(:group, parent: group1) }
    let(:wiki1) { create(:group_wiki, group: group1) }
    let(:wiki2) { create(:group_wiki, group: group2) }
    let(:wiki3) { create(:group_wiki, group: group3) }
    let(:wiki4) { create(:group_wiki, group: subgrp) }

    subject(:index_group_wikis) { service.execute(:index_group_wikis) }

    context 'when on GitLab.com', :saas do
      it 'raises an error' do
        expect { index_group_wikis }.to raise_error('This task cannot be run on GitLab.com')
      end
    end

    context 'with limited indexing disabled' do
      before do
        [wiki1, wiki2, wiki3, wiki4].each do |w|
          w.create_page('index_page', 'Bla bla term')
          w.index_wiki_blobs
        end
      end

      it 'calls ElasticWikiIndexerWorker for groups' do
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group1.id, group1.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group2.id, group2.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group3.id, group3.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(subgrp.id, subgrp.class.name, 'force' => true)

        index_group_wikis
      end
    end

    context 'with limited indexing enabled' do
      before do
        create(:elasticsearch_indexed_namespace, namespace: group1)
        create(:elasticsearch_indexed_namespace, namespace: group3)

        stub_ee_application_setting(elasticsearch_limit_indexing: true)

        [wiki1, wiki2, wiki3, wiki4].each do |w|
          w.create_page('index_page', 'Bla bla term')
          w.index_wiki_blobs
        end
      end

      it 'calls ElasticWikiIndexerWorker for groups which has elasticsearch enabled' do
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group1.id, group1.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group3.id, group3.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(subgrp.id, subgrp.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).not_to receive(:perform_async)
          .with group2.id, group2.class.name, 'force' => true

        index_group_wikis
      end
    end
  end

  describe '#index_group_entities' do
    subject(:index_group_entities) { service.execute(:index_group_entities) }

    context 'when on GitLab.com', :saas do
      it 'raises an error' do
        expect { index_group_entities }.to raise_error('This task cannot be run on GitLab.com')
      end
    end

    it 'calls other tasks in order' do
      expect(service).to receive(:index_epics).ordered
      expect(service).to receive(:index_group_wikis).ordered

      index_group_entities
    end
  end

  describe '#index_vulnerabilities' do
    let_it_be(:vulnerability_read) { create(:vulnerability_read) }

    context 'when vulnerability indexing is not allowed' do
      before do
        allow(::Search::Elastic::VulnerabilityIndexingHelper)
          .to receive(:vulnerability_indexing_allowed?).and_return(false)
      end

      it 'skips indexing and logs warning' do
        expect(logger).to receive(:info).with('Indexing vulnerabilities...')
        expect(logger).to receive(:info).with(/Skipping vulnerability indexing/)
        expect(::Vulnerabilities::Read).not_to receive(:all)

        service.execute(:index_vulnerabilities)
      end
    end

    shared_examples 'it performs indexing' do
      it 'calls track! for vulnerabilities' do
        expect(logger).to receive(:info).with(/Indexing vulnerabilities/).twice
        expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!).with(vulnerability_read)

        service.execute(:index_vulnerabilities)
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { service.execute(:index_vulnerabilities) }

        create_list(:vulnerability_read, 3)

        expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!)

        expect { service.execute(:index_vulnerabilities) }.to issue_same_number_of_queries_as(control).or_fewer
      end
    end

    context 'when rails env is dev' do
      before do
        stub_rails_env('development')
      end

      it_behaves_like 'it performs indexing'
    end

    context 'when vulnerability indexing is allowed' do
      before do
        allow(::Search::Elastic::VulnerabilityIndexingHelper)
          .to receive(:vulnerability_indexing_allowed?).and_return(true)
      end

      it_behaves_like 'it performs indexing'
    end
  end

  describe '#clear_index_status' do
    it 'deletes all records for Elastic::GroupIndexStatus and IndexStatus tables' do
      expect(Elastic::GroupIndexStatus).to receive(:delete_all)
      expect(IndexStatus).to receive(:delete_all)

      expect(logger).to receive(:info).with(/Index status has been reset/)

      service.execute(:clear_index_status)
    end
  end

  describe '#info', :elastic do
    let(:helper) { es_helper }
    let(:settings) { ::Gitlab::CurrentSettings }

    subject(:info) { service.execute(:info) }

    before do
      settings.update!(elasticsearch_search: true, elasticsearch_indexing: true)

      allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive_messages(ping?: true, get_meta: { 'created_by' => '123' })
    end

    it 'outputs GitLab version' do
      expect(logger).to receive(:info).with(/GitLab version:\s+\d+\.\d+\.\d+/)

      info
    end

    it 'outputs server version' do
      expect(logger).to receive(:info).with(/Server version:\s+\d+.\d+.\d+/)

      info
    end

    it 'outputs server distribution' do
      expect(logger).to receive(:info).with(/Server distribution:\s+\w+/)

      info
    end

    it 'outputs indexing and search settings' do
      expected_regex = [
        /Indexing enabled:\s+yes/,
        /Search enabled:\s+yes/,
        /Requeue Indexing workers:\s+no/,
        /Pause indexing:\s+no/,
        /Indexing restrictions enabled:\s+no/
      ]

      expected_regex.each do |expected|
        expect(logger).to receive(:info).with(expected)
      end

      info
    end

    it 'outputs file size limit' do
      expect(logger).to receive(:info).with(/File size limit:\s+\d+ KiB/)

      info
    end

    it 'outputs index version' do
      expect(logger).to receive(:info).with(/Index version:\s+\d+/)

      info
    end

    it 'outputs indexing number of shards' do
      expect(logger).to receive(:info).with(/Indexing number of shards:\s+\d+/)

      info
    end

    it 'outputs max code indexing concurrency' do
      expect(logger).to receive(:info).with(/Max code indexing concurrency:\s+\d+/)

      info
    end

    it 'outputs queue sizes' do
      allow(Elastic::ProcessInitialBookkeepingService).to receive(:queue_size).and_return(100)
      allow(Elastic::ProcessBookkeepingService).to receive(:queue_size).and_return(200)
      allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:queue_size)
        .with('Search::Elastic::CommitIndexerWorker')
        .and_return(75)

      expect(logger).to receive(:info).with(/Initial queue:\s+100/)
      expect(logger).to receive(:info).with(/Incremental queue:\s+200/)
      expect(logger).to receive(:info).with(/Concurrency limit code queue:\s+75/)

      info
    end

    describe 'pending migration status' do
      it 'outputs pending migrations' do
        pending_migration = ::Elastic::DataMigrationService.migrations.last
        obsolete_migration = ::Elastic::DataMigrationService.migrations.first
        allow(pending_migration).to receive(:completed?).and_return(false)
        allow(obsolete_migration).to receive_messages(completed?: false, obsolete?: true)
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations)
          .and_return([pending_migration, obsolete_migration])

        expect(logger).to receive(:info).with(/Pending Migrations/)
        expect(logger).to receive(:info).with(/#{pending_migration.name}/)
        expect(logger).to receive(:warn).with(/#{obsolete_migration.name} \[Obsolete\]/)

        info
      end

      context 'when search service is unreachable' do
        before do
          allow(helper).to receive(:ping?).and_return(false)
        end

        it 'outputs an error' do
          expect(logger).to receive(:info).with(/Pending Migrations/)
          expect(logger).to receive(:error).with(/Unable to connect to search cluster to retrieve data/)

          info
        end
      end
    end

    describe 'current migration status' do
      it 'outputs current migration' do
        migration = ::Elastic::DataMigrationService.migrations.last
        allow(migration).to receive_messages(started?: true, load_state: { test: 'value' })
        allow(Elastic::MigrationRecord).to receive(:current_migration).and_return(migration)

        expected_regex = [
          /Name:\s+#{migration.name}/,
          /Started:\s+yes/,
          /Halted:\s+no/,
          /Failed:\s+no/,
          /Obsolete:\s+no/,
          /Current state:\s+{"test":"value"}/
        ]

        # avoid printing pending migrations
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([])

        expected_regex.each do |expected|
          expect(logger).to receive(:info).with(expected)
        end

        info
      end

      context 'when there is no current migration' do
        it 'outputs a message stating no current migration' do
          expect(logger).to receive(:info).with(/Current Migration/)
          expect(logger).to receive(:info).with(/There is no current migration/)

          info
        end
      end

      context 'when search service is unreachable' do
        before do
          allow(helper).to receive(:ping?).and_return(false)
        end

        it 'outputs an error' do
          expect(logger).to receive(:info).with(/Current Migration/)
          expect(logger).to receive(:error).with(/Unable to connect to search cluster to retrieve data/)

          info
        end
      end
    end

    describe 'current reindexing tasks status' do
      it 'outputs current reindexing task' do
        task = create(:elastic_reindexing_task, targets: [Project, Issue])

        expect(logger).to receive(:info).with(/Current Zero-downtime Reindexing Tasks/)
        expect(logger).to receive(:info)
          .with(/Reindexing task started at: #{task.created_at} with targets: \[Project, Issue\]/)

        info
      end

      context 'when there is no current reindexing task' do
        it 'outputs a message stating no current reindexing task' do
          expect(logger).to receive(:info).with(/Current Zero-downtime Reindexing Tasks/)
          expect(logger).to receive(:info).with(/There is no current reindexing task/)

          info
        end
      end

      context 'when an error occurs while retrieving reindexing task data' do
        before do
          allow(::Search::Elastic::ReindexingTask).to receive(:current).and_raise(StandardError.new('Database error'))
        end

        it 'outputs an error' do
          expect(logger).to receive(:info).with(/Current Zero-downtime Reindexing Tasks/)
          expect(logger).to receive(:error)
            .with(/An exception occurred during the retrieval of the data: StandardError: Database error/)

          info
        end
      end
    end

    describe 'index settings' do
      let(:helper) { es_helper }
      let(:setting) do
        ::Elastic::IndexSetting.new(number_of_replicas: 1, number_of_shards: 8, alias_name: 'gitlab-test')
      end

      before do
        allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
        allow(::Elastic::IndexSetting).to receive(:every_alias).and_return([setting])
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([])
      end

      it 'outputs failed index setting' do
        allow(helper.client).to receive(:indices).and_raise(Timeout::Error)

        expect(logger).to receive(:error).with(/failed to load indices for gitlab-test/)

        info
      end

      it 'outputs index settings' do
        allow(helper).to receive(:documents_count).and_return(1000)

        indices = instance_double(Elasticsearch::API::Indices::IndicesClient)
        allow(helper.client).to receive(:indices).and_return(indices)
        allow(indices).to receive(:stats).with(index: setting.alias_name).and_return({
          "indices" => {
            "index" => {
              "primaries" => {
                "docs" => {
                  "count" => 1000
                }
              }
            }
          }
        })
        allow(indices).to receive(:get_settings).with(index: setting.alias_name).and_return({
          setting.alias_name => {
            "settings" => {
              "index" => {
                "number_of_shards" => 5,
                "number_of_replicas" => 1,
                "refresh_interval" => '2s',
                "blocks" => {
                  "write" => 'true'
                }
              }
            }
          }
        })

        expected_regex = [/#{setting.alias_name}:/,
          /document_count: 1000/,
          /number_of_shards: 5/,
          /number_of_replicas: 1/,
          /refresh_interval: 2s/]

        expected_regex.each do |expected|
          expect(logger).to receive(:info).with(expected)
        end
        expect(logger).to receive(:error).with(/blocks.write: yes/)

        info
      end
    end

    context 'when the search client throws an error' do
      it 'logs an error message and does not raise an error' do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_raise(StandardError)

        expect(logger).to receive(:error).with(/An exception occurred during the retrieval of the data/)
        expect { info }.not_to raise_error
      end
    end
  end

  describe '#disable_search_with_elasticsearch' do
    let(:settings) { ::Gitlab::CurrentSettings }

    subject(:disable_search_with_elasticsearch) { service.execute(:disable_search_with_elasticsearch) }

    context 'when elasticsearch_search is enabled' do
      it 'disables `elasticsearch_search`' do
        settings.update!(elasticsearch_search: true)

        expect { disable_search_with_elasticsearch }
          .to change { Gitlab::CurrentSettings.elasticsearch_search? }.from(true).to(false)
      end
    end

    context 'when elasticsearch_search is not enabled' do
      it 'does nothing' do
        settings.update!(elasticsearch_search: false)

        expect { disable_search_with_elasticsearch }.not_to change { Gitlab::CurrentSettings.elasticsearch_search? }
      end
    end
  end

  describe '#reindex_cluster' do
    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    subject(:reindex_cluster) { service.execute(:reindex_cluster) }

    it 'creates a reindexing task and queues the cron worker' do
      expect(::Search::Elastic::ReindexingTask).to receive(:create!)
      expect(::ElasticClusterReindexingCronWorker).to receive(:perform_async)

      expect(logger).to receive(:info).with(/Reindexing job was successfully scheduled/)

      reindex_cluster
    end

    context 'when elasticsearch_indexing is false' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'does nothing and logs an warning' do
        expect(::ElasticClusterReindexingCronWorker).not_to receive(:perform_async)

        expect(logger).to receive(:warn).with(/Setting `elasticsearch_indexing` is disabled/)

        reindex_cluster
      end
    end

    context 'when a reindexing task is in progress' do
      it 'logs an error' do
        ::Search::Elastic::ReindexingTask.create!

        expect(::ElasticClusterReindexingCronWorker).not_to receive(:perform_async)

        expect(logger).to receive(:error).with(/There is another task in progress. Please wait for it to finish/)

        reindex_cluster
      end
    end
  end

  describe '#recreate_index' do
    subject(:recreate_index) { service.execute(:recreate_index) }

    it 'calls delete_index and create_empty_index' do
      expect(service).to receive(:delete_index).ordered
      expect(service).to receive(:create_empty_index).ordered

      recreate_index
    end
  end

  describe '#clear_reindex_status' do
    subject(:clear_reindex_status) { service.execute(:clear_reindex_status) }

    it 'calls deletes all reindex records' do
      create(:elastic_reindexing_task)

      expect { clear_reindex_status }.to change { ::Search::Elastic::ReindexingTask.count }.from(1).to(0)
    end
  end

  def get_class_proxy(class_name:, use_separate_indices:)
    type_class(class_name) || ::Elastic::Latest::ApplicationClassProxy.new(class_name,
      use_separate_indices: use_separate_indices)
  end

  def type_class(class_name)
    [::Search::Elastic::Types, class_name].join('::').safe_constantize
  end
end
