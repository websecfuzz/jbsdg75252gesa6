# frozen_string_literal: true

FactoryBot.define do
  factory :system_access_instance_microsoft_application, class: 'SystemAccess::InstanceMicrosoftApplication' do
    enabled { true }
    tenant_xid { generate(:token) }
    client_xid { generate(:token) }
    client_secret { generate(:token) }
  end
end
