# frozen_string_literal: true

class Groups::BillingsController < Groups::ApplicationController
  include GitlabSubscriptions::SeatCountAlert

  before_action :verify_authorization
  before_action :verify_subscriptions_available!

  before_action only: [:index] do
    push_frontend_feature_flag(:refresh_billings_seats, type: :ops)
  end

  before_action only: :index do
    @seat_count_data = generate_seat_count_alert_data(@group)
  end

  layout 'group_settings'

  feature_category :subscription_management
  urgency :low

  def index
    @hide_search_settings = true
    @top_level_group = @group.root_ancestor if @group.has_parent?
    relevant_group = (@top_level_group || @group)
    current_plan = relevant_group.plan_name_for_upgrading
    @plans_data = GitlabSubscriptions::FetchSubscriptionPlansService
      .new(plan: current_plan, namespace_id: relevant_group.id)
      .execute
    @targeted_message_id = targeted_message_id

    unless @plans_data
      render 'shared/billings/customers_dot_unavailable'
    end
  end

  def refresh_seats
    if Feature.enabled?(:refresh_billings_seats, type: :ops)
      success = update_subscription_seats
    end

    if success
      render json: { success: true }
    else
      render json: { success: false }, status: :bad_request
    end
  end

  private

  def verify_subscriptions_available!
    render_404 unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
  end

  def update_subscription_seats
    gitlab_subscription = group.gitlab_subscription

    return false unless gitlab_subscription

    gitlab_subscription.refresh_seat_attributes
    gitlab_subscription.save
  end

  def verify_authorization
    authorize_billings_page!
  end

  def targeted_message_id
    return unless Feature.enabled?(:targeted_messages_admin_ui, :instance) &&
      ::Gitlab::Saas.feature_available?(:targeted_messages)

    return unless @group.owned_by?(current_user)

    Notifications::TargetedMessageNamespace.by_namespace_for_user(@group, current_user).pick(:targeted_message_id)
  end
end
