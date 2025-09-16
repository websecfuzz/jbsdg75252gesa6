# frozen_string_literal: true

module Gitlab
  module Geo
    # Finds a Model class associated with a String, which can be a parameter received by a controller
    # The string needs to match the model name, as defined by the Replicators
    #
    # Examples:
    # find_from_name("packages_package_file") returns Packages::PackageFile
    # convert_to_name(Packages::PackageFile) returns "packages_package_file"
    class ModelMapper
      class << self
        include Gitlab::Utils::StrongMemoize

        # Used by the Replicator to format a model name for API usage
        # @return [String] the snake_case representation of the passed Model class
        def convert_to_name(model)
          model.name.underscore.tr('/', '_')
        end

        # Used by the controller to get an ActiveRecord model from a passed parameter
        # @return [Class] the Model class matching the passed string, or nil
        def find_from_name(model_name)
          return unless model_name.is_a?(String)

          model_matching_hash[model_name.downcase]
        end

        private

        def model_matching_hash
          Gitlab::Geo::Replicator.subclasses.map(&:model).index_by { |model| convert_to_name(model) }
        end
        strong_memoize_attr :model_matching_hash
      end
    end
  end
end
