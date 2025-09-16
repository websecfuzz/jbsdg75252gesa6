# frozen_string_literal: true

FactoryBot.define do
  factory :ai_troubleshoot_job_event, class: '::Ai::TroubleshootJobEvent' do
    event { 'troubleshoot_job' }
    user
    association :job, factory: :ci_build
  end
end
