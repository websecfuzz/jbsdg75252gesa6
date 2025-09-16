# frozen_string_literal: true

FactoryBot.define do
  factory :project_secrets_manager, class: 'SecretsManagement::ProjectSecretsManager' do
    project
  end
end
