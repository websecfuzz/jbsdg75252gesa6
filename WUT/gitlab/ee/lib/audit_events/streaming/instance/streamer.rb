# frozen_string_literal: true

module AuditEvents
  module Streaming
    module Instance
      class Streamer < BaseStreamer
        def streamable?
          ::License.feature_available?(:external_audit_events) &&
            AuditEvents::Instance::ExternalStreamingDestination.active.exists?
        end

        def destinations
          AuditEvents::Instance::ExternalStreamingDestination.active.limit(5)
        end
      end
    end
  end
end
