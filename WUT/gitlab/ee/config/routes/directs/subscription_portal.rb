# frozen_string_literal: true

direct :subscriptions_comparison do
  Gitlab::Saas.about_feature_comparison_url
end

direct :subscription_portal_legacy_sign_in do
  Addressable::URI.join(subscription_portal_url, '/customers/sign_in?legacy=true').to_s
end

direct :subscription_portal_payment_form do
  Addressable::URI.join(subscription_portal_url, '/payment_forms/cc_validation').to_s
end

direct :subscription_portal_manage do
  Addressable::URI.join(subscription_portal_url, '/subscriptions').to_s
end

direct :subscription_portal_graphql do
  Addressable::URI.join(subscription_portal_url, '/graphql').to_s
end

direct :subscription_portal_more_minutes do
  Addressable::URI.join(subscription_portal_url, '/buy_pipeline_minutes').to_s
end

direct :subscription_portal_more_storage do
  Addressable::URI.join(subscription_portal_url, '/buy_storage').to_s
end

direct :subscription_portal_gitlab_plans do
  Addressable::URI.join(subscription_portal_url, '/gitlab_plans').to_s
end

direct :subscription_portal_edit_account do
  Addressable::URI.join(subscription_portal_url, '/customers/edit').to_s
end

direct :subscription_portal_billing_accounts do
  Addressable::URI.join(subscription_portal_url, '/billing_accounts').to_s
end

direct :subscription_portal_add_extra_seats do |group_id|
  Addressable::URI.join(subscription_portal_url, "/gitlab/namespaces/#{group_id}/extra_seats").to_s
end

direct :subscription_portal_add_saas_duo_pro_seats do |group_id|
  Addressable::URI.join(subscription_portal_url, "/gitlab/namespaces/#{group_id}/duo_pro_seats").to_s
end

direct :subscription_portal_add_sm_duo_pro_seats do |subscription_name|
  Addressable::URI.join(subscription_portal_url, "/gitlab/subscriptions/#{subscription_name}/duo_pro_seats").to_s
end

direct :subscription_portal_upgrade_subscription do |group_id, plan_id|
  Addressable::URI.join(subscription_portal_url, "/gitlab/namespaces/#{group_id}/upgrade/#{plan_id}").to_s
end

direct :subscription_portal_renew_subscription do |group_id|
  Addressable::URI.join(subscription_portal_url, "/gitlab/namespaces/#{group_id}/renew").to_s
end

direct :subscription_portal_new_subscription do
  Addressable::URI.join(subscription_portal_url, "/subscriptions/new").to_s
end

direct :subscription_portal_new_trial do |params|
  uri = Addressable::URI.join(subscription_portal_url, '/trials/new')
  uri.query_values = params if params.present?
  uri.to_s
end
