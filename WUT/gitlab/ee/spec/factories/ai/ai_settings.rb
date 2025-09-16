# frozen_string_literal: true

FactoryBot.define do
  factory :ai_settings, class: '::Ai::Setting' do
    ai_gateway_url { "http://0.0.0.0:5052" }
  end
end
