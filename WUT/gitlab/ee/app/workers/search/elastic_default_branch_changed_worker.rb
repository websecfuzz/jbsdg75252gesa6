# frozen_string_literal: true

module Search
  class ElasticDefaultBranchChangedWorker
    include ApplicationWorker
    include Search::Worker
    include Gitlab::EventStore::Subscriber
    prepend ::Geo::SkipSecondary

    data_consistency :delayed
    urgency :low
    idempotent!

    def handle_event(event)
      return unless ::Gitlab::CurrentSettings.elasticsearch_indexing?

      klass = event.data[:container_type].safe_constantize
      object = klass.find_by_id(event.data[:container_id])
      return unless object&.try(:use_elasticsearch?)

      enqueue_indexing(object)
    end

    private

    def enqueue_indexing(object)
      case object
      when Project
        object.repository.index_commits_and_blobs
      when GroupWiki, ProjectWiki
        object.index_wiki_blobs
      end
    end
  end
end
