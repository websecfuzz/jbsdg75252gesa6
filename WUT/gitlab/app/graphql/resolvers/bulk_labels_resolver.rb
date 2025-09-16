# frozen_string_literal: true

module Resolvers
  class BulkLabelsResolver < BaseResolver
    type Types::LabelType.connection_type, null: true

    def resolve
      bulk_load_labels
    end

    def object
      case super
      when ::WorkItems::Widgets::Base
        super.work_item
      else
        super
      end
    end

    private

    def bulk_load_labels
      BatchLoader::GraphQL.for(object.id).batch(key: object.class.name, cache: false) do |ids, loader, args|
        labels = Label.for_targets(object.class.id_in(ids)).group_by(&:target_id)

        ids.each do |id|
          loader.call(id, labels[id] || [])
        end
      end
    end
  end
end

Resolvers::BulkLabelsResolver.prepend_mod
