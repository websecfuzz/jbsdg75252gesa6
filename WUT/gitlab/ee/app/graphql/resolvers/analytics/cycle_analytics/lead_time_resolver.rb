# frozen_string_literal: true

# rubocop:disable Graphql/ResolverType -- inherited from Resolvers::Analytics::CycleAnalytics::BaseIssueResolver
module Resolvers
  module Analytics
    module CycleAnalytics
      class LeadTimeResolver < BaseIssueStageResolver
        METRIC_CLASS = Gitlab::Analytics::CycleAnalytics::Summary::LeadTime

        private

        def formatted_data(metric)
          super.merge(
            identifier: :lead_time,
            title: _('Lead time')
          )
        end
      end
    end
  end
end
# rubocop:enable Graphql/ResolverType
