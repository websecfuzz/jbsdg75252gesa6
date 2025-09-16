# frozen_string_literal: true

module EE
  module Search
    module Filter
      extend ::Gitlab::Utils::Override

      private

      override :filters
      def filters
        super.merge(
          **basic_filters,
          **label_filters,
          **branch_filters,
          **author_filters,
          **milestone_filters,
          **assignee_filters,
          **code_search_filters,
          **knn_filters
        )
      end

      def basic_filters
        {
          type: params[:type],
          fields: params[:fields],
          source: params[:source]
        }
      end

      def label_filters
        {
          # NOTE: label_name is used to convert names to ids and query ES by ids
          # It's deprecated, please use label_names instead
          label_name: params[:label_name],
          # NOTE: label_names searches ES by actual label names
          label_names: params[:label_names],
          not_label_names: params[:not_label_names],
          or_label_names: params[:or_label_names],
          none_label_names: params[:none_label_names],
          any_label_names: params[:any_label_names]
        }
      end

      def branch_filters
        {
          source_branch: params[:source_branch],
          not_source_branch: params[:not_source_branch],
          target_branch: params[:target_branch],
          not_target_branch: params[:not_target_branch]
        }
      end

      def author_filters
        {
          author_username: params[:author_username],
          not_author_username: params[:not_author_username]
        }
      end

      def milestone_filters
        {
          milestone_title: params[:milestone_title],
          none_milestones: params[:none_milestones],
          any_milestones: params[:any_milestones],
          not_milestone_title: params[:not_milestone_title]
        }
      end

      def assignee_filters
        {
          assignee_ids: params[:assignee_ids],
          not_assignee_ids: params[:not_assignee_ids],
          or_assignee_ids: params[:or_assignee_ids],
          none_assignees: params[:none_assignees],
          any_assignees: params[:any_assignees]
        }
      end

      def code_search_filters
        {
          language: params[:language],
          num_context_lines: params[:num_context_lines]&.to_i
        }
      end

      def knn_filters
        {
          hybrid_similarity: params[:hybrid_similarity]&.to_f,
          hybrid_boost: params[:hybrid_boost]&.to_f
        }
      end
    end
  end
end
