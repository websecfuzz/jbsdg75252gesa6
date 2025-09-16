# frozen_string_literal: true

module Vulnerabilities
  class ProjectsGrade
    attr_reader :vulnerable, :grade, :project_ids, :include_subgroups

    # project_ids can contain IDs from projects that do not belong to vulnerable, they will be filtered out in `projects` method
    def initialize(vulnerable, letter_grade, project_ids = [], include_subgroups: false)
      @vulnerable = vulnerable
      @grade = letter_grade
      @project_ids = project_ids
      @include_subgroups = include_subgroups
    end

    delegate :count, to: :projects

    def projects
      return Project.none if project_ids.blank?

      projects = include_subgroups ? vulnerable.all_projects : vulnerable.projects
      projects = projects.non_archived
      projects.with_vulnerability_statistics.inc_routes.where(id: project_ids)
    end

    # rubocop:disable Metrics/PerceivedComplexity -- temporary until we remove the feature flag and refactor
    # rubocop:disable Metrics/CyclomaticComplexity -- temporary until we remove the feature flag and refactor
    def self.grades_for(vulnerables, filter: nil, include_subgroups: false)
      # collect vulnerability statistics as relations
      relations = vulnerables.map do |vulnerable|
        if vulnerable.is_a?(Group)
          if include_subgroups
            ::Vulnerabilities::Statistic.by_group(vulnerable).unarchived
          else
            ::Vulnerabilities::Statistic.by_group_excluding_subgroups(vulnerable).unarchived
          end
        elsif vulnerable.is_a?(InstanceSecurityDashboard)
          Vulnerabilities::Statistic.for_project(vulnerable.non_archived_project_ids)
        else
          collection = include_subgroups ? vulnerable.all_projects : vulnerable.projects
          collection = collection.non_archived
          ::Vulnerabilities::Statistic.for_project([collection].reduce(&:or))
            .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/503387')
        end
      end

      # collect hashes that map letter grades to project IDs
      grades_maps = relations.map do |relation|
        relation = relation.by_grade(filter) if filter
        relation.group(:letter_grade)
                .select(:letter_grade, 'array_agg(project_id) project_ids')
                .then do |rows|
                  rows.each_with_object({}) do |row, statistics|
                    statistics[row.letter_grade] ||= []
                    statistics[row.letter_grade] += row.project_ids
                  end
                end
      end

      # map letter grades to project IDs across all vulnerables
      grades_to_project_ids = grades_maps.each_with_object({}) do |result, stats|
        result.each do |grade, project_ids|
          stats[grade] ||= []
          stats[grade] += project_ids
        end
      end

      # Currently all vulnerables get the same grades, but this behavior should be changed
      # as part of https://gitlab.com/gitlab-org/gitlab/-/issues/507992.
      vulnerables.index_with do |vulnerable|
        grades_to_project_ids.map { |letter_grade, project_ids| new(vulnerable, letter_grade, project_ids, include_subgroups: include_subgroups) }
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
  end
end
