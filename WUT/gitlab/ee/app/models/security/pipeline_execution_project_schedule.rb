# frozen_string_literal: true

module Security
  class PipelineExecutionProjectSchedule < ApplicationRecord
    include EachBatch

    MAX_TIME_WINDOW = 1.month.freeze

    before_create :set_next_run_at

    self.table_name = 'security_pipeline_execution_project_schedules'

    belongs_to :project
    belongs_to :security_policy, class_name: 'Security::Policy'

    validates :security_policy, :project, :cron, :cron_timezone, :time_window_seconds, presence: true
    validates :cron, cron: true
    validates :cron_timezone, cron_timezone: true
    validates :time_window_seconds,
      numericality: { greater_than_or_equal_to: 10.minutes.to_i, less_than_or_equal_to: MAX_TIME_WINDOW.to_i,
                      only_integer: true }

    validate :security_policy_is_pipeline_execution_schedule_policy

    scope :for_project, ->(project) { where(project: project) }
    scope :runnable_schedules, -> { where(next_run_at: ...Time.zone.now) }
    scope :ordered_by_next_run_at, -> { order(:next_run_at, :id) }
    scope :including_security_policy_and_project, -> { includes(:security_policy, :project) }
    scope :for_policy, ->(policy) { where(security_policy: policy) }

    def schedule_next_run!
      set_next_run_at
      save!
    end

    def ci_content
      security_policy.content["content"]
    end

    def next_run_in
      time_now = Time.zone.now

      (calculate_next_run_at(time_now) - time_now).to_i
    end

    def snoozed?
      return false unless snoozed_until

      snoozed_until.future?
    end

    def branches
      return [project.default_branch_or_main] if branches_content.nil?

      branches_content
    end

    private

    def branches_content
      # Using the first schedule because we only support one schedule per policy right now.
      # We might want to support multiple schedules in the future, which would require
      # changes to this code.
      schedule_content = security_policy.content['schedules']&.first

      return unless schedule_content['branches'].present?

      schedule_content['branches'].uniq
    end

    def timezone
      security_policy.content.dig('schedule', 'timezone')
    end

    def set_next_run_at
      self.next_run_at = calculate_next_run_at(Time.zone.now)
    end

    def calculate_next_run_at(from_time)
      Gitlab::Ci::CronParser
        .new(cron, cron_timezone)
        .next_time_from(from_time)
    end

    def security_policy_is_pipeline_execution_schedule_policy
      return unless security_policy

      return if security_policy.type_pipeline_execution_schedule_policy?

      errors.add(:security_policy,
        _("Security policy must be of type pipeline_execution_schedule_policy"))
    end
  end
end
