# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Update
      class Updater
        include Messages
        include States

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.update(context)
          context => { workspace: RemoteDevelopment::Workspace => workspace, params: Hash => params }
          model_errors = nil

          ApplicationRecord.transaction do
            begin
              workspace.personal_access_token.revoke! if params.fetch(:desired_state) == TERMINATED
            rescue ActiveRecord::ActiveRecordError
              model_errors = workspace.personal_access_token.errors
              raise ActiveRecord::Rollback
            end

            workspace.update(params)

            if workspace.errors.present?
              model_errors = workspace.errors
              raise ActiveRecord::Rollback
            end
          end

          return Gitlab::Fp::Result.err(WorkspaceUpdateFailed.new({ errors: model_errors })) if model_errors.present?

          Gitlab::Fp::Result.ok(WorkspaceUpdateSuccessful.new({ workspace: workspace }))
        end
      end
    end
  end
end
