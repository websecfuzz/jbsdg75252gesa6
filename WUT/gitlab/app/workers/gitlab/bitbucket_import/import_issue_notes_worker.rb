# frozen_string_literal: true

module Gitlab
  module BitbucketImport
    class ImportIssueNotesWorker # rubocop:disable Scalability/IdempotentWorker
      include ObjectImporter

      def importer_class
        Importers::IssueNotesImporter
      end
    end
  end
end
