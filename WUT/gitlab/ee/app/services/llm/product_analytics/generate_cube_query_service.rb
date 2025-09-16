# frozen_string_literal: true

module Llm
  module ProductAnalytics
    class GenerateCubeQueryService < BaseService
      private

      def ai_action
        :generate_cube_query
      end

      def perform
        schedule_completion_worker
      end

      def valid?
        super && Ability.allowed?(user, :generate_cube_query, resource)
      end
    end
  end
end
