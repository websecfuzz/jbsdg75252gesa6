# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_connection, class: 'Ai::ActiveContext::Connection' do
    sequence(:name) { |n| "connection_#{n}" }
    adapter_class { 'Ai::ActiveContext::Adapters::BaseAdapter' }
    active { true }
    options { { url: 'https://example.com', token: 'secret' } }
    prefix { 'test' }

    trait :inactive do
      active { false }
    end
  end
end
