# frozen_string_literal: true

module QA
  module EE
    FactoryBot.define do
      # https://docs.gitlab.com/ee/api/epics.html
      factory :epic, class: 'QA::EE::Resource::Epic' do
        trait :confidential do
          confidential { true }
        end
      end
    end
  end
end
