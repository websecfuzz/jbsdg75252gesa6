# frozen_string_literal: true

FactoryBot.define do
  factory :license do
    transient do
      plan { nil }
      expired { false }
      trial { false }
      seats { nil }
    end

    data do
      traits = []
      traits << :trial if trial
      traits << :expired if expired
      traits << :cloud if cloud

      build(:gitlab_license, *traits, plan: plan, seats: seats).export
    end

    # Disable validations when creating an expired license key
    to_create { |instance| instance.save!(validate: !expired) }
  end
end
