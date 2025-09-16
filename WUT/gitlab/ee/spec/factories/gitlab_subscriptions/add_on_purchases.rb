# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_subscription_add_on_purchase, class: 'GitlabSubscriptions::AddOnPurchase' do
    add_on { association(:gitlab_subscription_add_on) }
    organization { namespace ? namespace.organization : association(:organization, :default) }
    namespace { association(:group) }
    quantity { 1 }
    started_at { Time.current }
    expires_on { 60.days.from_now }
    purchase_xid { SecureRandom.hex(16) }
    trial { false }

    trait :active do
      started_at { 1.day.ago.to_date }
      expires_on { 1.year.from_now.to_date }
    end

    trait :trial do
      trial { true }
      expires_on { 60.days.from_now.to_date }
    end

    trait :active_trial do
      trial
      active
    end

    trait :expired do
      started_at { 5.days.ago.to_date }
      expires_on { 1.day.ago.to_date }
    end

    trait :expired_trial do
      trial
      expired
    end

    trait :future_dated do
      started_at { 1.month.from_now.to_date }
      expires_on { 1.year.from_now.to_date }
    end

    trait :product_analytics do
      add_on { association(:gitlab_subscription_add_on, :product_analytics) }
    end

    trait :duo_core do
      add_on { association(:gitlab_subscription_add_on, :duo_core) }
    end

    trait :duo_pro do
      add_on { association(:gitlab_subscription_add_on, :duo_pro) }
    end

    trait :duo_enterprise do
      add_on { association(:gitlab_subscription_add_on, :duo_enterprise) }
    end

    trait :duo_amazon_q do
      add_on { association(:gitlab_subscription_add_on, :duo_amazon_q) }
    end

    trait :duo_self_hosted do
      add_on { association(:gitlab_subscription_add_on, :duo_self_hosted) }
    end

    trait :self_managed do
      namespace { nil }
    end
  end
end
