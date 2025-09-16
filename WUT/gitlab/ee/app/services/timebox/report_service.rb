# frozen_string_literal: true

module Timebox
  # ReportService can generate burnchart data and stats for a timebox.
  #
  # 1. `Timebox::EventAggregationService` fetches -
  #     resource events (e.g., ResourceStateEvent) for issues and tasks for a timebox.
  # 2. `Gitlab::Timebox::SnapshotBuilder` reconstructs the ending states of issues and tasks for a timebox
  #     for each date in the timebox using the fetched resource events.
  #     A Snapshot contains the point-in-time states of issues and tasks for a date.
  # 3. Each Snapshot can be turned into `Gitlab::Timebox::BurnchartDataPoint`, a data point for a burnchart.
  class ReportService
    NULL_STATS_DATA = {
      incomplete: { count: 0, weight: 0 },
      complete: { count: 0, weight: 0 },
      total: { count: 0, weight: 0 }
    }.freeze

    def initialize(timebox, scoped_projects = nil)
      @timebox = timebox
      @scoped_projects = scoped_projects
    end

    def execute
      # There is no data to return for fake timeboxes like
      # Milestone::None, Milestone::Any, Milestone::Started, Milestone::Upcoming,
      # Iteration::None, Iteration::Any, Iteration::Current
      return success if timebox.is_a?(::Timebox::TimeboxStruct)
      return error(:unsupported_type) unless timebox.supports_timebox_charts?
      return error(:missing_dates) if timebox.start_date.blank? || timebox.due_date.blank?

      agg_service_response = Timebox::EventAggregationService.new(timebox, scoped_projects).execute
      return agg_service_response unless agg_service_response.success?

      resource_events = agg_service_response.payload[:resource_events]
      snapshots = Gitlab::Timebox::SnapshotBuilder.new(timebox, resource_events).build
      chart_data = Gitlab::Timebox::BurnchartDataPoint.build_data(timebox, snapshots).map(&:to_h)

      success(chart_data: chart_data)
    end

    private

    attr_reader :timebox, :scoped_projects

    def success(chart_data: [])
      ServiceResponse.success(payload: {
        burnup_time_series: chart_data,
        stats: build_stats(chart_data)
      })
    end

    def error(code)
      message = case code
                when :unsupported_type
                  format(_('%{timebox_type} does not support burnup charts'), timebox_type: timebox_type)
                when :missing_dates
                  format(_('%{timebox_type} must have a start and due date'), timebox_type: timebox_type)
                end

      ServiceResponse.error(message: message, payload: { code: code })
    end

    def timebox_type
      timebox.class.name
    end

    def build_stats(chart_data)
      stats_data = chart_data.last
      return NULL_STATS_DATA unless stats_data

      {
        complete: {
          count: stats_data[:completed_count],
          weight: stats_data[:completed_weight]
        },
        incomplete: {
          count: stats_data[:scope_count] - stats_data[:completed_count],
          weight: stats_data[:scope_weight] - stats_data[:completed_weight]
        },
        total: {
          count: stats_data[:scope_count],
          weight: stats_data[:scope_weight]
        }
      }
    end
  end
end
