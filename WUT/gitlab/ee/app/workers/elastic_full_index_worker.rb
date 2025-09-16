# frozen_string_literal: true

# For each project in range,
# indexing the repository, wiki and its nested models
# (e.g. )issues and notes etc.)
# Intended for full site indexing.
class ElasticFullIndexWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  include Search::Worker
  prepend ::Geo::SkipSecondary

  data_consistency :always
  pause_control :advanced_search

  sidekiq_options retry: 2

  def perform(start_id, end_id)
    return true unless Gitlab::CurrentSettings.elasticsearch_indexing?

    Project.id_in(start_id..end_id).find_each do |project|
      Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
    end
  end
end
