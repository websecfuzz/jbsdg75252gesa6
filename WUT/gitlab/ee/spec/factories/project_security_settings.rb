# frozen_string_literal: true

FactoryBot.define do
  factory :project_security_setting do
    project { association :project, security_setting: instance }
    continuous_vulnerability_scans_enabled { false }
    container_scanning_for_registry_enabled { false }
    secret_push_protection_enabled { false }
  end
end
