# frozen_string_literal: true

FactoryBot.define do
  factory :targeted_message, class: 'Notifications::TargetedMessage' do
    target_type { :banner_page_level }

    namespaces { [association(:namespace)] }
  end
end
