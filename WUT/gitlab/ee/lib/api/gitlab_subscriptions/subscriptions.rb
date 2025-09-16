# frozen_string_literal: true

module API
  module GitlabSubscriptions
    class Subscriptions < ::API::Base
      feature_category :plan_provisioning
      urgency :low

      before do
        @namespace = find_namespace(params[:id])

        not_found!('Namespace') unless @namespace
      end

      resource :namespaces, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
        desc '[DEPRECATED] Create a subscription for the namespace' do
          success ::API::Entities::GitlabSubscription
        end
        params do
          requires :start_date, type: Date, desc: 'The date when subscription was started'
          optional :end_date, type: Date, desc: 'End date of subscription'
          optional :plan_code, type: String, desc: 'Subscription tier code'

          optional :seats, type: Integer, desc: 'Number of seats in subscription'
          optional :max_seats_used, type: Integer, desc: 'Highest number of active users in the last month'
          optional :auto_renew, type: Grape::API::Boolean, desc: 'Whether subscription will auto renew on end date'

          optional :trial, type: Grape::API::Boolean, desc: 'Whether the subscription is a trial'
          optional :trial_ends_on, type: Date, desc: 'End date of trial'
          optional :trial_starts_on, type: Date, desc: 'Start date of trial'
          optional :trial_extension_type, type: Integer, desc: 'Whether the trial was extended or reactivated'
        end
        post ":id/gitlab_subscription", urgency: :low, feature_category: :plan_provisioning do
          subscription_params = declared_params(include_missing: false)

          subscription_params[:trial_starts_on] ||= subscription_params[:start_date] if subscription_params[:trial]

          subscription = @namespace.create_gitlab_subscription(subscription_params)

          if subscription.persisted?
            present subscription, with: ::API::Entities::GitlabSubscription
          else
            render_validation_error!(subscription)
          end
        end

        desc '[DEPRECATED] Update the subscription for the namespace' do
          success ::API::Entities::GitlabSubscription
        end
        params do
          optional :start_date, type: Date, desc: 'Start date of subscription'
          optional :end_date, type: Date, desc: 'End date of subscription'
          optional :plan_code, type: String, desc: 'Subscription tier code'

          optional :seats, type: Integer, desc: 'Number of seats in subscription'
          optional :max_seats_used, type: Integer, desc: 'Highest number of active users in the last month'
          optional :auto_renew, type: Grape::API::Boolean, desc: 'Whether subscription will auto renew on end date'

          optional :trial, type: Grape::API::Boolean, desc: 'Whether the subscription is a trial'
          optional :trial_ends_on, type: Date, desc: 'End date of trial'
          optional :trial_starts_on, type: Date, desc: 'Start date of trial'
          optional :trial_extension_type, type: Integer, desc: 'Whether the trial was extended or reactivated'
        end
        put ":id/gitlab_subscription" do
          subscription = @namespace.gitlab_subscription

          not_found!('GitlabSubscription') unless subscription

          subscription_params = declared_params(include_missing: false)
          subscription_params[:trial_starts_on] ||= subscription_params[:start_date] if subscription_params[:trial]
          subscription_params[:updated_at] = Time.current

          if subscription.update(subscription_params)
            present subscription, with: ::API::Entities::GitlabSubscription
          else
            render_validation_error!(subscription)
          end
        end
      end
    end
  end
end
