# frozen_string_literal: true

FactoryBot.define do
  factory :ai_agent, class: '::Ai::Agent' do
    sequence(:name) { |n| "agent#{n}" }
    project
  end
end
