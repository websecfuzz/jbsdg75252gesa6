# frozen_string_literal: true

FactoryBot.define do
  factory :cloud_connector_access, class: 'CloudConnector::Access' do
    data do
      {
        available_services: [
          {
            name: "code_suggestions",
            serviceStartTime: "2024-02-15T00:00:00Z",
            bundledWith: %w[duo_pro]
          },
          {
            name: "duo_chat",
            serviceStartTime: nil,
            bundledWith: %w[duo_pro]
          }
        ]
      }
    end

    catalog do
      Gitlab::CloudConnector::DataModel.load_all.except(:services)
    end

    trait :current do
      updated_at { Time.current }
    end

    trait :stale do
      updated_at { Time.current - ::CloudConnector::Access::STALE_PERIOD - 1.minute }
    end
  end
end
