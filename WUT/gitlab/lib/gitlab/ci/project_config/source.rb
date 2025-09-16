# frozen_string_literal: true

module Gitlab
  module Ci
    class ProjectConfig
      class Source
        include Gitlab::Utils::StrongMemoize

        def initialize(
          project:, sha:, custom_content: nil, pipeline_source: nil, pipeline_source_bridge: nil,
          triggered_for_branch: false, ref: nil, inputs: {})
          @project = project
          @sha = sha
          @custom_content = custom_content
          @pipeline_source = pipeline_source
          @pipeline_source_bridge = pipeline_source_bridge
          @triggered_for_branch = triggered_for_branch
          @ref = ref
          @inputs = inputs
        end

        def exists?
          strong_memoize(:exists) do
            content.present?
          end
        end

        def content
          raise NotImplementedError
        end

        # Indicates if we are prepending the content with an "internal" `include`
        def internal_include_prepended?
          false
        end

        def source
          raise NotImplementedError
        end

        def url
          nil
        end

        def inputs_for_pipeline_creation
          # For internal_include_prepended?, we already pass the inputs to the `include` statement.
          internal_include_prepended? ? {} : inputs
        end

        private

        attr_reader :project, :sha, :custom_content, :pipeline_source, :pipeline_source_bridge, :triggered_for_branch,
          :ref, :inputs

        def ci_config_path
          @ci_config_path ||= project.ci_config_path_or_default
        end

        def ci_yaml_include(config)
          YAML.dump('include' => [config.merge(include_inputs)])
        end

        def include_inputs
          { inputs: inputs }
            .compact_blank
            .deep_stringify_keys # to avoid symbols in the YAML
        end
      end
    end
  end
end

Gitlab::Ci::ProjectConfig::Source.prepend_mod
