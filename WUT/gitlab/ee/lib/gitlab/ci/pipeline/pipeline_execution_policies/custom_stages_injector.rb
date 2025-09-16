# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module PipelineExecutionPolicies
        # This class is responsible for injecting custom stages defined by execution policy pipelines
        # into the CI config's stages. It uses DAG ordering to merge stages from multiple pipelines.
        class CustomStagesInjector
          InvalidStageConditionError = Class.new(StandardError)

          class << self
            # Injects custom policy stages into the CI config
            #
            # @param config_stages [Array] CI config stages
            # @param injected_policy_stages [Array<Array>] List of stages for each `inject_policy` policy pipeline
            # @return [Array] Merged project and policy stages
            def inject(config_stages, injected_policy_stages)
              project_tree = generate_tree(config_stages)
              policy_trees = injected_policy_stages.flat_map do |stages|
                generate_tree(stages)
              end

              dependency_tree = merge_trees([project_tree, *policy_trees])
              ::Gitlab::Ci::YamlProcessor::Dag.order(dependency_tree) # rubocop:disable CodeReuse/ActiveRecord -- not an ActiveRecord object
            rescue TSort::Cyclic
              raise InvalidStageConditionError, 'Pipeline execution policy error: ' \
                'Cyclic dependencies detected when enforcing policies. ' \
                'Ensure stages across the project and policies are aligned.' \
            end

            private

            def generate_tree(stages)
              stages.each_with_object({}).with_index do |(stage, tree), index|
                # Build a map where each stage has a dependency on all of its previous stages.
                previous_stages = stages[0...index]
                tree[stage] = previous_stages
              end
            end

            def merge_trees(trees)
              trees.each_with_object({}) do |tree, hash|
                tree.each do |stage, dependencies|
                  # Merge dependencies of each stage from all pipelines.
                  # This allows us to catch cyclic dependencies when we merge trees for each pipeline.
                  # When we perform `Dag.order`, each stage is placed after all stages it depends on.
                  hash[stage] = Array.wrap(hash[stage]) | dependencies
                end
              end
            end
          end
        end
      end
    end
  end
end
