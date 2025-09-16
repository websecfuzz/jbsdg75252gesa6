# frozen_string_literal: true

module AuditEvents
  module Streaming
    module Destinations
      class HttpStreamDestination < BaseStreamDestination
        STREAMING_TOKEN_HEADER_KEY = "X-Gitlab-Event-Streaming-Token"

        def stream
          Gitlab::HTTP.post(
            destination.config["url"],
            body: request_body,
            headers: build_headers,
            **::AuditEvents::HttpTimeoutConfig::DEFAULT
          )
        rescue URI::InvalidURIError, *Gitlab::HTTP::HTTP_ERRORS => e
          Gitlab::ErrorTracking.log_exception(e)
        end

        private

        def build_headers
          headers = @destination.headers_hash
          headers[EVENT_TYPE_HEADER_KEY] = @event_type if @event_type.present?
          headers
        end
      end
    end
  end
end
