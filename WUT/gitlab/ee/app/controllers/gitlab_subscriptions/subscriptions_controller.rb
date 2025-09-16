# frozen_string_literal: true

module GitlabSubscriptions
  class SubscriptionsController < ApplicationController
    include InternalRedirect
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include ActionView::Helpers::SanitizeHelper

    SUCCESS_SUBSCRIPTION = 'Success: subscription'
    SUCCESS_ADDON = 'Success: add-on'

    layout 'minimal'

    # Skip user authentication if the user is currently verifying their identity
    # by providing a payment method as part of a three-stage (payment method,
    # phone number, and email verification) identity verification process.
    # Authentication is skipped since active_for_authentication? is false at
    # this point and becomes true only after the user completes the verification
    # process.
    before_action :authenticate_user!, except: :new, unless: :identity_verification_request?

    feature_category :subscription_management
    urgency :low

    def new
      return ensure_registered! unless current_user.present?

      namespace = find_eligible_namespace(id: params[:namespace_id], any_self_service_plan: true)

      redirect_to purchase_url(plan_id: sanitize(params[:plan_id]), namespace: namespace)
    end

    def buy_minutes
      add_on_purchase_flow(plan_tag: 'CI_1000_MINUTES_PLAN', transaction_param: 'ci_minutes')
    end

    def buy_storage
      add_on_purchase_flow(plan_tag: 'STORAGE_PLAN', transaction_param: 'storage')
    end

    def payment_form
      response = client.payment_form_params(params[:id], current_user&.id)
      render json: response[:data]
    end

    def payment_method
      response = client.payment_method(params[:id])
      render json: response[:data]
    end

    def validate_payment_method
      user_id = identity_verification_request? ? identity_verification_user.id : current_user.id

      response = client.validate_payment_method(params[:id], { gitlab_user_id: user_id })

      render json: response
    end

    def create
      current_user.update(onboarding_status_setup_for_company: true) if params[:setup_for_company]
      group = params[:selected_group] ? current_group : create_group

      return not_found if group.nil?

      unless group.persisted?
        track_purchase message: group.errors.full_messages.to_s
        return render json: group.errors.to_json
      end

      response = GitlabSubscriptions::CreateService.new(
        current_user,
        group: group,
        customer_params: customer_params,
        subscription_params: subscription_params,
        idempotency_key: params[:idempotency_key]
      ).execute

      if response[:success]
        track_purchase message: track_success_message, namespace: group
        response[:data] = { location: redirect_location(group) }
      else
        track_purchase message: response.dig(:data, :errors), namespace: group
      end

      render json: response[:data]
    end

    private

    def purchase_url(plan_id:, namespace:, **params)
      GitlabSubscriptions::PurchaseUrlBuilder.new(plan_id: plan_id, namespace: namespace).build(**params)
    end

    def add_on_purchase_flow(plan_tag:, transaction_param:)
      plan_id = plan_id_for_tag(tag: plan_tag)

      return render_404 unless plan_id.present?

      namespace = find_eligible_namespace(id: params[:selected_group], plan_id: plan_id)

      return render_404 unless namespace.present?

      redirect_to purchase_url(plan_id: plan_id, namespace: namespace, transaction: transaction_param)
    end

    def track_purchase(message:, namespace: nil)
      Gitlab::Tracking.event(
        self.class.name,
        'click_button',
        label: 'confirm_purchase',
        property: message,
        user: current_user,
        namespace: namespace
      )
    end

    def track_success_message
      addon? ? SUCCESS_ADDON : SUCCESS_SUBSCRIPTION
    end

    def addon?
      Gitlab::Utils.to_boolean(subscription_params[:is_addon], default: false)
    end

    def redirect_location(group)
      return safe_redirect_path(params[:redirect_after_success]) if params[:redirect_after_success]

      plan_id, quantity = subscription_params.values_at(:plan_id, :quantity)
      return group_billings_path(group, plan_id: plan_id, purchased_quantity: quantity) if params[:selected_group]

      edit_gitlab_subscriptions_group_path(
        group.path, plan_id: plan_id, quantity: quantity, new_user: params[:new_user]
      )
    end

    def customer_params
      params.require(:customer).permit(:country, :address_1, :address_2, :city, :state, :zip_code, :company)
    end

    def subscription_params
      params.require(:subscription)
            .permit(:plan_id, :is_addon, :payment_method_id, :quantity, :source, :promo_code)
            .merge(params.permit(:active_subscription))
    end

    def find_group(plan_id:)
      selected_group = current_user.owned_groups.top_level.find(params[:selected_group])

      result = GitlabSubscriptions::FetchPurchaseEligibleNamespacesService
        .new(user: current_user, plan_id: plan_id, namespaces: Array(selected_group))
        .execute

      return {} unless result.success?

      result.payload.first || {}
    end

    def find_eligible_namespace(id:, any_self_service_plan: nil, plan_id: nil)
      namespace = current_user.owned_groups.top_level.with_counts(archived: false).find_by_id(id)

      return unless namespace.present? && GitlabSubscriptions::FetchPurchaseEligibleNamespacesService.eligible?(
        user: current_user,
        namespace: namespace,
        any_self_service_plan: any_self_service_plan,
        plan_id: plan_id
      )

      namespace
    end

    def current_group
      find_group(plan_id: subscription_params[:plan_id])[:namespace]
    end

    def create_group
      name = Namespace.clean_name(params[:setup_for_company] ? customer_params[:company] : current_user.name)
      path = Namespace.clean_path(name)

      response = Groups::CreateService.new(
        current_user, name: name, path: path, organization_id: Current.organization.id
      ).execute

      response[:group]
    end

    def client
      Gitlab::SubscriptionPortal::Client
    end

    def plan_id_for_tag(tag:)
      plan_response = client.get_plans(tags: [tag])

      plan_response[:success] ? plan_response[:data].first['id'] : nil
    end

    def ensure_registered!
      store_location_for(:user, request.fullpath)

      redirect_to new_user_registration_path
    end

    def identity_verification_request?
      # true only for actions used to verify a user's credit card
      return false unless %w[payment_form validate_payment_method].include?(action_name)

      identity_verification_user.present? && !identity_verification_user.credit_card_verified?
    end

    def identity_verification_user
      strong_memoize(:identity_verification_user) do
        User.find_by_id(session[:verification_user_id])
      end
    end
  end
end

GitlabSubscriptions::SubscriptionsController.prepend_mod
