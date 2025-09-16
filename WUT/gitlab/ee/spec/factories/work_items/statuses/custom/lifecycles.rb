# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_custom_lifecycle, class: 'WorkItems::Statuses::Custom::Lifecycle' do
    association :namespace
    default_open_status { association :work_item_custom_status, :open, namespace: namespace }
    default_closed_status { association :work_item_custom_status, :closed, namespace: namespace }
    default_duplicate_status { association :work_item_custom_status, :duplicate, namespace: namespace }
    sequence(:name) { |n| "Custom Lifecycle #{n}" }

    # The `work_item_status` license should be enabled in order to use this trait
    trait :for_issues do
      after(:create) do |lifecycle|
        lifecycle.work_item_types << WorkItems::Type.default_by_type(:issue)
      end
    end

    # The `work_item_status` license should be enabled in order to use this trait
    trait :for_tasks do
      after(:create) do |lifecycle|
        lifecycle.work_item_types << WorkItems::Type.default_by_type(:task)
      end
    end
  end
end
