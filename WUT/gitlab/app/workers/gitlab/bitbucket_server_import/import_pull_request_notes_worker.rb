# frozen_string_literal: true

module Gitlab
  module BitbucketServerImport
    class ImportPullRequestNotesWorker # rubocop:disable Scalability/IdempotentWorker
      include ObjectImporter

      def importer_class
        Importers::PullRequestNotesImporter
      end
    end
  end
end
