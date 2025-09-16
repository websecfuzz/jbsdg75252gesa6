# frozen_string_literal: true

FactoryBot.modify do
  factory :user do
    trait :auditor do
      auditor { true }
    end

    trait :group_managed do
      association :managing_group, factory: :group_with_managed_accounts

      after(:create) do |user, evaluator|
        create(:group_saml_identity,
          user: user,
          saml_provider: user.managing_group.saml_provider
        )
      end
    end

    trait :service_user do
      user_type { :service_user }
    end

    trait :service_account do
      name { 'Service account user' }
      user_type { :service_account }
      skip_confirmation { true }
      email { "#{User::SERVICE_ACCOUNT_PREFIX}_#{generate(:username)}@#{User::NOREPLY_EMAIL_DOMAIN}" }
      association :provisioned_by_group, factory: :group
    end

    trait :low_risk do
      after(:create) do |user|
        create(:user_custom_attribute,
          key: UserCustomAttribute::ARKOSE_RISK_BAND, value: Arkose::VerifyResponse::RISK_BAND_LOW, user: user
        )
      end
    end

    trait :medium_risk do
      after(:create) do |user|
        create(:user_custom_attribute,
          key: UserCustomAttribute::ARKOSE_RISK_BAND, value: Arkose::VerifyResponse::RISK_BAND_MEDIUM, user: user
        )
      end
    end

    trait :high_risk do
      after(:create) do |user|
        create(:user_custom_attribute,
          key: UserCustomAttribute::ARKOSE_RISK_BAND, value: Arkose::VerifyResponse::RISK_BAND_HIGH, user: user
        )
      end
    end

    trait :identity_verification_eligible do
      created_at { IdentityVerifiable::IDENTITY_VERIFICATION_RELEASE_DATE + 1.day }
    end

    trait :with_compromised_password_detection do
      after(:create) do |user|
        create(:compromised_password_detection, user: user)
      end
    end

    trait :with_self_managed_duo_enterprise_seat do
      after(:create) do |user|
        subscription_purchase = create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed)

        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: subscription_purchase
        )
      end
    end
  end

  factory :omniauth_user do
    transient do
      saml_provider { nil }
    end

    trait :arkose_verified do
      after(:create) do |user|
        create(:user_custom_attribute,
          key: UserCustomAttribute::ARKOSE_RISK_BAND, value: Arkose::VerifyResponse::RISK_BAND_LOW, user: user
        )
      end
    end
  end
end

FactoryBot.define do
  factory :auditor, parent: :user, traits: [:auditor]
  factory :external_user, parent: :user, traits: [:external]
  factory :service_account, parent: :user, traits: [:service_account]
  factory :enterprise_user, parent: :user do
    transient do
      enterprise_group { association(:group) }
    end

    user_detail do
      association :user_detail, :enterprise, enterprise_group: enterprise_group, user: instance
    end
  end
end
