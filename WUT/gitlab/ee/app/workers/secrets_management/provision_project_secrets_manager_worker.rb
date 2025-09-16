# frozen_string_literal: true

module SecretsManagement
  class ProvisionProjectSecretsManagerWorker
    include ApplicationWorker

    data_consistency :sticky

    urgency :high

    idempotent!

    feature_category :secrets_management

    def perform(current_user_id, project_secrets_manager_id)
      ProjectSecretsManager.find_by_id(project_secrets_manager_id).try do |secrets_manager|
        user = User.find_by_id(current_user_id)
        next unless user

        ProjectSecretsManagers::ProvisionService.new(secrets_manager, user).execute
      end
    end
  end
end
