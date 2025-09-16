# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item_version, class: 'Ai::Catalog::ItemVersion' do
    version { 'v1.0.0' }
    schema_version { 1 }
    release_date { Time.current }
    definition { { 'system_prompt' => 'Talk like a pirate!', 'user_prompt' => 'What is a leap year?' } }
    item { association :ai_catalog_item }
  end
end
