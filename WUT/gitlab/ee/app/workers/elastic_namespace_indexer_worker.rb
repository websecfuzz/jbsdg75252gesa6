# frozen_string_literal: true

class ElasticNamespaceIndexerWorker
  include ApplicationWorker
  include Search::Worker
  prepend ::Geo::SkipSecondary

  data_consistency :delayed

  worker_resource_boundary :cpu
  deduplicate :until_executed
  idempotent!
  sidekiq_options retry: 2
  loggable_arguments 1
  pause_control :advanced_search

  def perform(namespace_id, operation)
    return true unless Gitlab::CurrentSettings.elasticsearch_indexing?

    namespace = Namespace.find_by_id(namespace_id)
    return unless namespace

    case operation.to_s
    when /index/
      index_projects(namespace)
      index_group_associations(namespace)
    when /delete/
      delete_from_index(namespace)
      delete_group_wikis(namespace) if should_maintain_group_wiki_index?(namespace)
    end
  end

  private

  def index_projects(namespace)
    namespace.all_projects.find_in_batches do |batch|
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(*batch)
    end
  end

  def index_group_wikis(namespace)
    namespace.self_and_descendants.find_each.with_index do |grp, idx|
      interval = idx % ElasticWikiIndexerWorker::MAX_JOBS_PER_HOUR
      ElasticWikiIndexerWorker.perform_in(interval, grp.id, grp.class.name, { 'force' => true })
    end
  end

  def index_group_associations(namespace)
    namespace.self_and_descendants.each_batch do |batch|
      Elastic::ProcessBookkeepingService.maintain_indexed_namespace_associations!(*batch)

      batch.group_namespaces.each.with_index do |namespace, idx|
        interval = idx % ElasticWikiIndexerWorker::MAX_JOBS_PER_HOUR
        ElasticWikiIndexerWorker.perform_in(interval, namespace.id, namespace.class.name, { 'force' => true })
      end
    end
  end

  def delete_from_index(namespace)
    namespace.all_projects.find_in_batches do |batch|
      args = batch.map { |project| [project.id, project.es_id, { delete_project: false }] }
      ElasticDeleteProjectWorker.bulk_perform_async(args) # rubocop:disable Scalability/BulkPerformWithContext -- namespace_id argument is logged, do not need to log each project id
    end

    return unless namespace.group_namespace?

    ancestor_id = namespace.root_ancestor.id
    namespace.self_and_descendants_ids.each.with_index do |namespace_id, idx|
      interval = idx % Search::ElasticGroupAssociationDeletionWorker::MAX_JOBS_PER_HOUR
      Search::ElasticGroupAssociationDeletionWorker.perform_in(interval, namespace_id, ancestor_id)
    end
  end

  def delete_group_wikis(namespace)
    namespace.self_and_descendants.find_each.with_index do |grp, idx|
      interval = idx % Search::Wiki::ElasticDeleteGroupWikiWorker::MAX_JOBS_PER_HOUR
      Search::Wiki::ElasticDeleteGroupWikiWorker.perform_in(interval, grp.id, "namespace_routing_id" => namespace.id)
    end
  end

  def should_maintain_group_wiki_index?(namespace)
    namespace.group_namespace?
  end
end
