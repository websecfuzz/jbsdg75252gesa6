# frozen_string_literal: true

module Snippets
  class BaseService < ::BaseProjectService
    UPDATE_COMMIT_MSG = 'Update snippet'
    INITIAL_COMMIT_MSG = 'Initial commit'
    INVALID_PARAMS_ERROR = :invalid_params_error
    INVALID_PARAMS_MESSAGES = {
      cannot_be_used_together: 'and snippet files cannot be used together',
      invalid_data: 'have invalid data'
    }.freeze
    SNIPPET_ACCESS_ERROR = :snippet_access_error

    CreateRepositoryError = Class.new(StandardError)

    attr_reader :uploaded_assets, :snippet_actions

    def initialize(project: nil, current_user: nil, params: {})
      super

      @uploaded_assets = Array(@params.delete(:files).presence)

      input_actions = Array(@params.delete(:snippet_actions).presence)
      @snippet_actions = SnippetInputActionCollection.new(input_actions, allowed_actions: restricted_files_actions)
    end

    private

    def visibility_allowed?(visibility_level)
      Gitlab::VisibilityLevel.allowed_for?(current_user, visibility_level)
    end

    def forbidden_visibility_error(snippet)
      deny_visibility_level(snippet)

      snippet_error_response(snippet, SNIPPET_ACCESS_ERROR)
    end

    def valid_params?
      return true if snippet_actions.empty?

      (params.keys & [:content, :file_name]).none? && snippet_actions.valid?
    end

    def invalid_params_error(snippet)
      if snippet_actions.valid?
        [:content, :file_name].each do |key|
          snippet.errors.add(key, INVALID_PARAMS_MESSAGES[:cannot_be_used_together]) if params.key?(key)
        end
      else
        snippet.errors.add(:snippet_actions, INVALID_PARAMS_MESSAGES[:invalid_data])
      end

      snippet_error_response(snippet, INVALID_PARAMS_ERROR)
    end

    def snippet_error_response(snippet, reason)
      ServiceResponse.error(
        message: snippet.errors.full_messages.to_sentence,
        reason: reason,
        payload: { snippet: snippet }
      )
    end

    def add_snippet_repository_error(snippet:, error:)
      message = repository_error_message(error)

      snippet.errors.add(:repository, message)
    end

    def repository_error_message(error)
      message = self.is_a?(Snippets::CreateService) ? _("Error creating the snippet") : _("Error updating the snippet")

      # We only want to include additional error detail in the message
      # if the error is not a CommitError because we cannot guarantee the message
      # will be user-friendly
      message += " - #{error.message}" unless error.instance_of?(SnippetRepository::CommitError)

      message
    end

    def file_paths_to_commit
      paths = []
      snippet_actions.to_commit_actions.each do |action|
        paths << { path: action[:file_path] }
      end

      paths
    end

    def files_to_commit(snippet)
      snippet_actions.to_commit_actions.presence || build_actions_from_params(snippet)
    end

    def build_actions_from_params(snippet)
      raise NotImplementedError
    end

    def restricted_files_actions
      nil
    end

    def commit_attrs(snippet, msg)
      {
        branch_name: snippet.default_branch,
        message: msg
      }
    end

    def delete_repository(snippet)
      snippet.repository.remove
      snippet.snippet_repository&.delete

      # Purge any existing value for repository_exists?
      snippet.repository.expire_exists_cache
    end
  end
end
