# frozen_string_literal: true

module Namespaces
  class StorageUsageExportWorker
    include ApplicationWorker

    feature_category :consumables_cost_management

    idempotent!
    deduplicate :until_executed
    urgency :low
    data_consistency :delayed
    loggable_arguments 0
    worker_resource_boundary :memory

    def perform(plan, user_id)
      user = User.find(user_id)

      result = Namespaces::Storage::UsageExportService.execute(plan, user)

      if result.success?
        Notify.namespace_storage_usage_csv_email(user, result.payload).deliver_now
      else
        logger.error("Failed to export namespace storage usage: #{result.message}")
      end
    rescue ActiveRecord::RecordNotFound
      logger.error("Failed to export namespace storage usage due to no user (id:#{user_id})")
    end
  end
end
