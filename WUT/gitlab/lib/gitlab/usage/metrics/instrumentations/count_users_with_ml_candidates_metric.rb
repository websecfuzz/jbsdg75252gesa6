# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        class CountUsersWithMlCandidatesMetric < DatabaseMetric
          operation :distinct_count, column: :user_id

          relation { Ml::Candidate }
        end
      end
    end
  end
end
