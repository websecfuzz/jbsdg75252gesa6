# frozen_string_literal: true

FactoryBot.define do
  factory :ai_usage_event, class: '::Ai::UsageEvent' do
    event { 'request_duo_chat_response' }
    association :user, :with_namespace
    namespace { user&.namespace }
    extras { {} }
  end
end
