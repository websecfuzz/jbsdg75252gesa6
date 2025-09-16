# frozen_string_literal: true

class NewEpicWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  data_consistency :always

  sidekiq_options retry: 3
  include NewIssuable

  feature_category :portfolio_management
  worker_resource_boundary :cpu
  weight 2

  def perform(epic_id, user_id); end

  def issuable_class
    Epic
  end
end
