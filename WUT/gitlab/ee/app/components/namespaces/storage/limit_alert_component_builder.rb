# frozen_string_literal: true

module Namespaces
  module Storage
    class LimitAlertComponentBuilder
      def self.build(context:, user:)
        if NamespaceLimit::Enforcement.enforce_limit?(context.root_ancestor)
          NamespaceLimit::AlertComponent.new(context: context, user: user)
        else
          RepositoryLimit::AlertComponent.new(context: context, user: user)
        end
      end
    end
  end
end
