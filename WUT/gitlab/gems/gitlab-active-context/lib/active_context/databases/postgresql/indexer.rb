# frozen_string_literal: true

module ActiveContext
  module Databases
    module Postgresql
      class Indexer
        include ActiveContext::Databases::Concerns::Indexer

        BATCH_SIZE = 1_000

        def initialize(...)
          super
          @operations = []
        end

        def add_ref(ref)
          @refs << ref
          build_operation(ref)

          refs.size >= BATCH_SIZE
        end

        def empty?
          refs.empty?
        end

        def bulk
          client.bulk_process(@operations)
        end

        def process_bulk_errors(result)
          result.uniq { |ref| ref.unique_identifier(nil) }
        end

        def reset
          super
          @operations = []
        end

        private

        def build_operation(ref)
          case ref.operation.to_sym
          when :upsert
            build_upsert_operations(ref)
            @operations << build_delete_operation(ref: ref, include_ref_version: true)
          when :update
            build_upsert_operations(ref)
          when :delete
            @operations << build_delete_operation(ref: ref)
          else
            raise StandardError, "Operation #{ref.operation} is not supported"
          end
        end

        def build_upsert_operations(ref)
          ref.jsons.each do |hash|
            @operations << { "#{ref.partition_name}": { upsert: build_indexed_json(hash, ref) }, ref: ref }
          end
        end

        def build_indexed_json(hash, ref)
          hash
            .merge(
              partition_id: ref.partition_number,
              id: hash[:unique_identifier]
            )
            .except(:unique_identifier)
            .transform_values { |value| convert_pg_array(value) }
        end

        def build_delete_operation(ref:, include_ref_version: false)
          hash = { ref_id: ref.identifier }
          hash[:ref_version] = ref.ref_version if include_ref_version

          { "#{ref.partition_name}": { delete: hash }, ref: ref }
        end

        def convert_pg_array(value)
          value.is_a?(Array) ? "[#{value.join(',')}]" : value
        end
      end
    end
  end
end
