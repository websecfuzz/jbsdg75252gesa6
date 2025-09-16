# frozen_string_literal: true

class SyncSeatLinkRequestWorker
  include ApplicationWorker

  data_consistency :always

  feature_category :plan_provisioning

  # Retry for up to approximately 2 days
  sidekiq_options retry: 20
  sidekiq_retry_in do |count, _exception|
    1.hour + rand(20.minutes)
  end

  idempotent!
  worker_has_external_dependencies!

  RequestError = Class.new(StandardError)

  def perform(timestamp, license_key, max_historical_user_count, billable_users_count, refresh_token = false)
    seat_link_data = Gitlab::SeatLinkData.new(
      timestamp: DateTime.parse(timestamp),
      key: license_key,
      max_users: max_historical_user_count,
      billable_users_count: billable_users_count,
      refresh_token: refresh_token
    )

    response = Gitlab::SubscriptionPortal::Client.create_seat_link(seat_link_data)

    raise RequestError, response['data']['errors'] unless response['success']

    response_data = response['data']
    license = find_or_create_cloud_license!(response_data['license']) if response_data['license']

    update_license_dependencies(response_data, license)
    update_reconciliation!(response_data)

    perform_cloud_connector_sync if refresh_token
  end

  private

  def perform_cloud_connector_sync
    ::CloudConnector::SyncServiceTokenWorker.perform_async(
      'license_id' => License.current.id,
      'force' => true
    )
  end

  def find_or_create_cloud_license!(license_key)
    License.reset_current

    if License.current_cloud_license?(license_key)
      license = License.current.reset
      license.touch(:last_synced_at)

      license
    else
      License.create!(data: license_key, cloud: true, last_synced_at: Time.current)
    end
  rescue StandardError => e
    Gitlab::ErrorTracking.track_and_raise_for_dev_exception(e)
  end

  def update_reconciliation!(response)
    reconciliation = GitlabSubscriptions::UpcomingReconciliation.next

    if response['next_reconciliation_date'].blank? || response['display_alert_from'].blank?
      reconciliation&.destroy!
    else
      attributes = {
        next_reconciliation_date: Date.parse(response['next_reconciliation_date']),
        display_alert_from: Date.parse(response['display_alert_from'])
      }

      if reconciliation
        reconciliation.update!(attributes)
      else
        GitlabSubscriptions::UpcomingReconciliation.create!(
          attributes.merge({ organization_id: Organizations::Organization.first.id })
        )
      end
    end
  end

  def update_license_dependencies(response, license)
    ::GitlabSubscriptions::UpdateLicenseDependenciesService.new(
      future_subscriptions: response['future_subscriptions'],
      license: license,
      new_subscription: response['new_subscription']
    ).execute
  end
end
