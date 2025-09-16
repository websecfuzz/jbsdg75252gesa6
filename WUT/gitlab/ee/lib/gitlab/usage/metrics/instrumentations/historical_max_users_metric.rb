# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        class HistoricalMaxUsersMetric < ::Gitlab::Usage::Metrics::Instrumentations::GenericMetric
          value do
            ::License.current.historical_max if ::License.current&.license?
          end
        end
      end
    end
  end
end
