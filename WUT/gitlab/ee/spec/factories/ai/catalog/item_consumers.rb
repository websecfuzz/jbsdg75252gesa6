# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item_consumer, class: 'Ai::Catalog::ItemConsumer' do
    item { association :ai_catalog_item }
    locked { true }
  end
end
