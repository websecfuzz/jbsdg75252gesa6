# frozen_string_literal: true

module Dora
  class AggregateScoresService < BaseContainerService
    include ::Gitlab::Utils::StrongMemoize

    def execute
      return ServiceResponse.error(message: _('Container must be a group.')) unless group_container?
      return authorization_error unless authorized?

      ServiceResponse.success(payload: { aggregations: aggregated_counts_by_metric,
                                         projects_without_dora_data_count: projects_without_any_scores_count })
    end

    def authorized_projects
      GroupProjectsFinder
        .new(group: group, current_user: current_user, options: { include_subgroups: true }, params: params)
        .execute
    end
    strong_memoize_attr :authorized_projects

    private

    def aggregated_counts_by_metric
      DailyMetrics::AVAILABLE_METRICS.map { |metric_name| counts_by_metric(metric_name) }
    end

    def counts_by_metric(metric_symbol)
      result = { metric_name: metric_symbol }
      counts = raw_counts(metric_symbol).with_indifferent_access

      # return all nils if we have no scores
      return result.merge(default_hash) if counts.empty?

      Dora::PerformanceScore::SCORES.each_key do |score|
        result[:"#{score}_projects_count"] = counts[score] || 0
      end

      # some projects have no scores at all (no performance score records) for the given time range
      # whereas some projects some scores for a subset of given metrics
      # we make sure we count them distinctly
      projects_without_scores_for_metric = counts[nil] || 0
      result[:no_data_projects_count] = projects_without_scores_for_metric
      result
    end

    def beginning_of_last_month
      Time.current.last_month.beginning_of_month
    end
    strong_memoize_attr :beginning_of_last_month

    def projects_without_any_scores_count
      return 0 if authorized_projects.empty?

      projects_without_any_dora_scores_count(
        date: beginning_of_last_month.to_date
      )
    end
    strong_memoize_attr :projects_without_any_scores_count

    def projects_without_any_dora_scores_count(date:)
      authorized_projects.select(:id).id_not_in(Project.with_dora_scores_for_date(date)).count
    end

    def raw_counts(metric_symbol)
      return {} if authorized_projects.empty?

      Dora::PerformanceScore.for_projects(authorized_projects)
        .for_dates(beginning_of_last_month)
        .group_counts_by_metric(metric_symbol)
    end

    def default_hash
      {
        low_projects_count: nil,
        medium_projects_count: nil,
        high_projects_count: nil,
        no_data_projects_count: authorized_projects.count
      }
    end

    def authorized?
      can?(current_user, :read_dora4_analytics, container)
    end

    def authorization_error
      ServiceResponse.error(message: _('You do not have permission to access DORA4 metrics.'))
    end
  end
end
