# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Tasks
        class Uploads < Task
          def self.id = 'uploads'

          def human_name = 'Uploads'

          def destination_path = 'uploads.tar.gz'

          private

          def local
            Gitlab::Backup::Cli::Targets::Files.new(context, storage_path, excludes: ['tmp'])
          end

          def storage_path = context.upload_path
        end
      end
    end
  end
end
