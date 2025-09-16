# frozen_string_literal: true

module WorkItems
  class ValidateEpicWorkItemSyncWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :delayed
    feature_category :team_planning
    urgency :low
    idempotent!

    def handle_event(event)
      # no-op - worker can be removed in 18.3
    end
  end
end
