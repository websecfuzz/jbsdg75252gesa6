# frozen_string_literal: true

module Gitlab
  module ContributionAnalytics
    class ClickHouseDataCollector
      include Gitlab::Utils::StrongMemoize

      attr_reader :group, :from, :to

      def initialize(group:, from:, to:)
        @group = group
        @from = from
        @to = to
      end

      def totals_by_author_target_type_action
        query = ::ClickHouse::Client::Query.new(raw_query: clickhouse_query, placeholders: placeholders)
        ::ClickHouse::Client.select(query, :main).each_with_object({}) do |row, hash|
          hash[[row['author_id'], row['target_type'].presence, row['action']]] = row['count']
        end
      end

      private

      def group_path
        # trailing slash required to denote end of path because we use startsWith
        # to get self and descendants
        group.traversal_path(with_organization: fetch_data_from_new_table)
      end

      def format_date(date)
        date.utc.to_date.iso8601
      end

      def contributions_table
        if fetch_data_from_new_table
          'contributions_new'
        else
          'contributions'
        end
      end
      strong_memoize_attr :contributions_table

      def fetch_data_from_new_table
        Feature.enabled?(:fetch_contributions_data_from_new_tables, group)
      end
      strong_memoize_attr :fetch_data_from_new_table

      def clickhouse_query
        <<~CH
          SELECT count(*) AS count,
            "#{contributions_table}"."author_id" AS author_id,
            "#{contributions_table}"."target_type" AS target_type,
            "#{contributions_table}"."action" AS action
          FROM (
            SELECT
              id,#{select_deleted_flag}
              argMax(author_id, #{contributions_table}.updated_at) AS author_id,
              CASE
                WHEN argMax(target_type, #{contributions_table}.updated_at) IN ('Issue', 'WorkItem') THEN 'Issue'
                ELSE argMax(target_type, #{contributions_table}.updated_at)
              END AS target_type,
              argMax(action, #{contributions_table}.updated_at) AS action
            FROM #{contributions_table}
              WHERE startsWith(path, {group_path:String})
              AND "#{contributions_table}"."created_at" >= {from:Date}
              AND "#{contributions_table}"."created_at" <= {to:Date}
              AND (
                (
                  "#{contributions_table}"."action" = 5 AND "#{contributions_table}"."target_type" = ''
                )
                OR
                (
                  "#{contributions_table}"."action" IN (1, 3, 7, 12)
                  AND "#{contributions_table}"."target_type" IN ('MergeRequest', 'Issue', 'WorkItem')
                )
              )
            GROUP BY id
          ) #{contributions_table} #{filter_deleted_flag}
          GROUP BY "#{contributions_table}"."action","#{contributions_table}"."target_type","#{contributions_table}"."author_id"
        CH
      end

      def select_deleted_flag
        if fetch_data_from_new_table
          %{\nargMax(deleted, #{contributions_table}.version) AS deleted,}
        else
          ''
        end
      end

      def filter_deleted_flag
        if fetch_data_from_new_table
          %(\nWHERE deleted = false)
        else
          ''
        end
      end

      def placeholders
        {
          group_path: group_path,
          from: format_date(from),
          to: format_date(to)
        }
      end
    end
  end
end
