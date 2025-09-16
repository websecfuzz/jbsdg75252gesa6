# frozen_string_literal: true

module EE
  module BulkImports
    module Projects
      module Stage
        extend ::Gitlab::Utils::Override

        private

        def ee_config
          {
            push_rule: {
              pipeline: ::BulkImports::Projects::Pipelines::PushRulePipeline,
              stage: 4
            },
            vulnerabilities: {
              pipeline: ::BulkImports::Projects::Pipelines::VulnerabilitiesPipeline,
              minimum_source_version: '17.7.0',
              stage: 6
            }
          }
        end

        override :config
        def config
          bulk_import.source_enterprise ? super.deep_merge(ee_config) : super
        end
      end
    end
  end
end
