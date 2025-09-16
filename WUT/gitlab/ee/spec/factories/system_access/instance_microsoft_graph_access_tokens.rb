# frozen_string_literal: true

FactoryBot.define do
  factory :system_access_instance_microsoft_graph_access_token,
    class: 'SystemAccess::InstanceMicrosoftGraphAccessToken' do
    system_access_instance_microsoft_application
    token { generate(:token) }
    expires_in { 3600 }
  end
end
