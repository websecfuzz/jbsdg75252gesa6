# frozen_string_literal: true

module Snippets
  class DestroyService
    include Gitlab::Allowable

    FAILED_TO_DELETE_ERROR = :failed_to_delete_error
    SNIPPET_NOT_FOUND_ERROR = :snippet_not_found_error
    SNIPPET_ACCESS_ERROR = :snippet_access_error

    attr_reader :current_user, :snippet

    DestroyError = Class.new(StandardError)

    def initialize(user, snippet)
      @current_user = user
      @snippet = snippet
    end

    def execute
      if snippet.nil?
        return service_response_error('No snippet found.', SNIPPET_NOT_FOUND_ERROR)
      end

      unless user_can_delete_snippet?
        return service_response_error(
          "You don't have access to delete this snippet.",
          SNIPPET_ACCESS_ERROR
        )
      end

      attempt_destroy!

      ServiceResponse.success(message: 'Snippet was deleted.')
    rescue DestroyError
      service_response_error('Failed to remove snippet repository.', FAILED_TO_DELETE_ERROR)
    rescue StandardError
      service_response_error('Failed to remove snippet.', FAILED_TO_DELETE_ERROR)
    end

    private

    def attempt_destroy!
      result = ::Repositories::DestroyService.new(snippet.repository).execute

      raise DestroyError if result[:status] == :error

      snippet.destroy!
    end

    def user_can_delete_snippet?
      can?(current_user, :admin_snippet, snippet)
    end

    def service_response_error(message, reason)
      ServiceResponse.error(message: message, reason: reason)
    end
  end
end

Snippets::DestroyService.prepend_mod_with('Snippets::DestroyService')
