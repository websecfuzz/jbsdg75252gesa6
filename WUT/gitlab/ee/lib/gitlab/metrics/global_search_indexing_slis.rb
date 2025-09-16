# frozen_string_literal: true

module Gitlab
  module Metrics
    module GlobalSearchIndexingSlis
      include Gitlab::Metrics::SliConfig

      sidekiq_enabled!

      CODE_DOCUMENT_TYPES = %w[Code Wiki].freeze

      # Non-Code indexing bytes/second should be above these values
      # Set to low values until https://gitlab.com/gitlab-org/gitlab/-/issues/390599 is implemented
      INCREMENTAL_INDEXED_BYTES_PER_SECOND_TARGET = 100
      INITIAL_INDEXED_BYTES_PER_SECOND_TARGET = 0

      # The following targets are the 99.95th percentile of indexing
      # gathered on 20-10-2022
      # Code/Wikis
      # from https://log.gprd.gitlab.net/goto/8cbc1920-3432-11ed-8656-f5f2137823ba (internal only)
      #
      # Other
      # (TODO) https://log.gprd.gitlab.net/goto/a6f274b0-3432-11ed-8656-f5f2137823ba (internal only)
      CONTENT_INDEXING_TARGET_S = 4.878
      CODE_INDEXING_TARGET_S    = 120.0

      class << self
        def initialize_slis!
          Gitlab::Metrics::Sli::Apdex.initialize_sli(:global_search_indexing, possible_labels)
        end

        def record_apdex(elapsed:, document_type:)
          Gitlab::Metrics::Sli::Apdex[:global_search_indexing].increment(
            labels: labels(document_type: document_type),
            success: elapsed < duration_target(document_type)
          )
        end

        def record_bytes_per_second_apdex(throughput:, target:)
          Gitlab::Metrics::Sli::Apdex[:global_search_indexing].increment(
            labels: labels(document_type: 'Database'),
            success: throughput >= target
          )
        end

        private

        def duration_target(document_type)
          CODE_DOCUMENT_TYPES.include?(document_type) ? CODE_INDEXING_TARGET_S : CONTENT_INDEXING_TARGET_S
        end

        def document_types
          indexable_models + CODE_DOCUMENT_TYPES
        end

        def indexable_models
          # This will gather the names of all classes that include Elastic::ApplicationVersionedSearch
          # Classes that include this module will be tracked and updated by ProcessBookkeepingService
          ::ApplicationRecord.descendants.filter_map do |model|
            model.to_s if model.include?(::Elastic::ApplicationVersionedSearch)
          end
        end

        def possible_labels
          document_types.map do |document_type|
            {
              document_type: document_type,
              indexed_by: indexed_by(document_type)
            }
          end
        end

        def labels(document_type:)
          {
            document_type: document_type,
            indexed_by: indexed_by(document_type)
          }
        end

        def indexed_by(document_type)
          CODE_DOCUMENT_TYPES.include?(document_type) ? 'indexer' : 'rails'
        end
      end
    end
  end
end
