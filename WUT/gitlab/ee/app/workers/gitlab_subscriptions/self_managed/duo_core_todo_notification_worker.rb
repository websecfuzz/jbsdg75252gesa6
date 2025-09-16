# frozen_string_literal: true

module GitlabSubscriptions
  module SelfManaged
    class DuoCoreTodoNotificationWorker
      include ApplicationWorker

      deduplicate :until_executed
      data_consistency :delayed
      idempotent!

      feature_category :acquisition

      def perform
        return unless ::Ai::Setting.duo_core_features_enabled?

        todo_service = TodoService.new

        # This is inline with how the admin area filters eligible users for other types of duo on the
        # seat utilization page.
        users = GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder.new(add_on_type: :duo_core).execute

        users.find_in_batches do |batch|
          # Short circuit this potentially long-running job if the setting is changed
          break unless ::Ai::Setting.duo_core_features_enabled?

          todo_service.duo_core_access_granted(batch)
        end
      end
    end
  end
end
