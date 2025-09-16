# frozen_string_literal: true

module QA
  module EE
    module Scenario
      module Test
        module Integration
          class Elasticsearch < QA::Scenario::Test::Instance::All
            tags :elasticsearch

            pipeline_mappings test_on_omnibus: %w[elasticsearch],
              test_on_omnibus_nightly: %w[
                integration-elasticsearch-compatibility-version-7
                integration-elasticsearch-compatibility-version-8
                integration-opensearch-compatibility-version-1
                integration-opensearch-compatibility-version-2
              ]
          end
        end
      end
    end
  end
end
