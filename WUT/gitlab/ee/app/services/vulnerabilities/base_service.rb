# frozen_string_literal: true

module Vulnerabilities
  class BaseService
    include Gitlab::Allowable

    def initialize(user, vulnerability)
      @user = user
      @vulnerability = vulnerability
      @project = vulnerability.project
    end

    private

    def update_vulnerability_with(params)
      @vulnerability.transaction do
        yield if block_given?

        raise ActiveRecord::Rollback unless @vulnerability.update(params)

        @changed = @vulnerability.previous_changes.present?

        # run_after_commit runs in the scope of the calling object, hence @user needs to be captured
        user = @user
        @vulnerability.run_after_commit do
          # The following service call alters the `previous_changes` of the vulnerability object
          # therefore, we are sending the cloned object as that information is important for the rest of the logic.
          SystemNoteService.change_vulnerability_state(clone, user)
        end
      end

      update_statistics
    end

    def update_statistics
      Vulnerabilities::StatisticsUpdateService.update_for(@vulnerability) if @changed
    end

    def authorized?
      can?(@user, :admin_vulnerability, @project)
    end
  end
end
