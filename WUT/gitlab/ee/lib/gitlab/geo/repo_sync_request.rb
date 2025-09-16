# frozen_string_literal: true

module Gitlab
  module Geo
    class RepoSyncRequest < BaseRequest
      def expiration_time
        120.minutes
      end
    end
  end
end
