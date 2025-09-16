# frozen_string_literal: true

FactoryBot.define do
  factory :ai_duo_chat_event, class: '::Ai::DuoChatEvent' do
    event { 'request_duo_chat_response' }
    association :user, :with_namespace
    payload { {} }
  end
end
