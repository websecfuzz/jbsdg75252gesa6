# frozen_string_literal: true

module Search
  module Elastic
    class ClusterReindexingService
      include Gitlab::Utils::StrongMemoize
      include Gitlab::Loggable

      INITIAL_INDEX_OPTIONS = { # Optimized for writes
        refresh_interval: '10s',
        number_of_replicas: 0,
        translog: { durability: 'async' }
      }.freeze

      DELETE_ORIGINAL_INDEX_AFTER = 14.days
      REINDEX_MAX_RETRY_LIMIT = 20
      REINDEX_SCROLL = '2h'

      def execute
        case current_task.state.to_sym
        when :initial
          initial!
        when :indexing_paused
          indexing_paused!
        when :reindexing
          reindexing!
        end
      end

      def current_task
        ::Search::Elastic::ReindexingTask.current
      end
      strong_memoize_attr :current_task

      private

      def default_index_options(alias_name:, index_name:)
        # Use existing refresh_interval setting or nil for default
        {
          refresh_interval: elastic_helper.get_settings(index_name: index_name)['refresh_interval'],
          number_of_replicas: ::Elastic::IndexSetting[alias_name].number_of_replicas,
          translog: { durability: 'request' }
        }
      end

      def initial!
        return false unless elasticsearch_indexing_enabled?
        return false unless no_pending_migrations?

        # Pause indexing
        ::Gitlab::CurrentSettings.update!(elasticsearch_pause_indexing: true)

        return false unless elasticsearch_alias_exists?
        return false unless sufficient_storage_available?

        current_task.update!(state: :indexing_paused)

        true
      end

      def elasticsearch_indexing_enabled?
        return true if ::Gitlab::CurrentSettings.elasticsearch_indexing?

        abort_reindexing!('Elasticsearch indexing is disabled')
        false
      end

      def no_pending_migrations?
        return true if !::Elastic::DataMigrationService.pending_migrations? ||
          current_task.options[:skip_pending_migrations_check]

        # migrations may have paused indexing so we do not want to unpause when aborting the reindexing process
        abort_reindexing!('You have unapplied advanced search migrations. ' \
          'Please wait until it is finished', unpause_indexing: false)
        false
      end

      def elasticsearch_alias_exists?
        return true if elastic_helper.alias_exists?

        abort_reindexing!('Your Elasticsearch index must first use aliases before you can use this feature. ' \
          'Please recreate your index from scratch before reindexing.')
        false
      end

      def sufficient_storage_available?
        expected_free_size = current_index_size * 2
        return true if elastic_helper.cluster_free_size_bytes >= expected_free_size

        abort_reindexing!("You should have at least #{expected_free_size} bytes of storage available to perform " \
          "reindexing. Please increase the storage in your Elasticsearch cluster before reindexing.")
        false
      end

      def current_index_size
        current_task.target_classes.sum do |klass|
          name = elastic_helper.klass_to_alias_name(klass: klass)
          elastic_helper.index_size_bytes(index_name: name)
        end
      end

      def indexing_paused!
        items_to_reindex = []

        current_task.target_classes.each do |klass|
          alias_name = elastic_helper.klass_to_alias_name(klass: klass)
          index_names = elastic_helper.target_index_names(target: alias_name).keys

          index_names.each_with_index do |index_name, index|
            name_suffix = "-reindex-#{current_task.id}-#{index}"

            alias_info = load_alias_info(klass: klass, name_suffix: name_suffix)

            items_to_reindex << {
              alias_name: alias_info.each_value.first,
              index_name_from: index_name,
              index_name_to: alias_info.each_key.first
            }
          end
        end

        launch_subtasks(items_to_reindex)

        current_task.update!(state: :reindexing)

        true
      end

      def load_alias_info(klass:, name_suffix:)
        if klass == Repository # Repository is a marker class for the main index
          elastic_helper.create_empty_index(
            with_alias: false,
            options: { settings: INITIAL_INDEX_OPTIONS, name_suffix: name_suffix }
          )
        else
          elastic_helper.create_standalone_indices(
            with_alias: false,
            options: { settings: INITIAL_INDEX_OPTIONS, name_suffix: name_suffix },
            target_classes: [klass]
          )
        end
      end

      def launch_subtasks(items_to_reindex)
        items_to_reindex.each do |item|
          subtask = current_task.subtasks.create!(item)

          number_of_shards = elastic_helper.get_settings(index_name: item[:index_name_from])['number_of_shards'].to_i
          max_slice = number_of_shards * current_task.slice_multiplier
          max_slice.times do |slice|
            subtask.slices.create!(elastic_max_slice: max_slice, elastic_slice: slice)
          end
        end

        trigger_reindexing_slices
      end

      def save_documents_count!(refresh:)
        current_task.subtasks.each do |subtask|
          subtask.update!(
            documents_count: elastic_helper.documents_count(index_name: subtask.index_name_from, refresh: refresh),
            documents_count_target: elastic_helper.documents_count(index_name: subtask.index_name_to, refresh: refresh)
          )
        end
      end

      def check_subtasks_and_reindex_slices
        save_documents_count!(refresh: false)

        slices_failed = 0
        slices_in_progress = 0
        totals_do_not_match = 0

        current_task.subtasks.each do |subtask|
          subtask.slices.started.each do |slice|
            # Get task status
            task_status = ::Search::Elastic::TaskStatus.new(task_id: slice.elastic_task)

            # Check if task is complete
            slices_in_progress += 1 unless task_status.completed?

            # Check for reindexing error
            if task_status.error?
              slices_failed += 1

              logged_arguments = {
                task_id: slice.elastic_task,
                elasticsearch_error_type: task_status.error_type,
                elasticsearch_failures: task_status.failures,
                slice: slice.elastic_slice
              }

              retry_or_abort_after_limit(subtask, slice, 'Task failed', **logged_arguments)
              slices_in_progress += 1

              next
            end

            # Check totals match if task complete
            next unless task_status.completed? && !task_status.totals_match?

            logged_arguments = {
              task_id: slice.elastic_task,
              slice: slice.elastic_slice,
              total_count: task_status.counts[:total],
              created_count: task_status.counts[:created],
              updated_count: task_status.counts[:updated],
              deleted_count: task_status.counts[:deleted]
            }
            retry_or_abort_after_limit(subtask, slice, 'Task totals not equal', **logged_arguments)

            slices_in_progress += 1
            totals_do_not_match += 1
          end
        end

        # Kick off more reindexing slices
        slices_in_progress = trigger_reindexing_slices(slices_in_progress)

        # Schedule another check in 1 minute
        ::ElasticClusterReindexingCronWorker.perform_in(1.minute)

        slices_in_progress == 0 && slices_failed == 0 && totals_do_not_match == 0
      rescue Elasticsearch::Transport::Transport::Error
        abort_reindexing!("Couldn't load task status")

        false
      end

      def retry_or_abort_after_limit(subtask, slice, message, additional_logs)
        if slice.retry_attempt < REINDEX_MAX_RETRY_LIMIT
          retry_slice(subtask, slice, "#{message} Retrying.")
        else
          abort_reindexing!("#{message}. Retry limit reached. Aborting reindexing.",
            additional_logs: additional_logs)
        end
      end

      def retry_slice(subtask, slice, message, additional_options = {})
        logger.warn(build_structured_payload(message: message,
          gitlab_task_id: current_task.id,
          gitlab_task_state: current_task.state,
          gitlab_subtask_id: subtask.id,
          index_from: subtask.index_name_from,
          index_to: subtask.index_name_to,
          slice: slice.elastic_slice,
          task_id: slice.elastic_task,
          **additional_options))

        task_id = elastic_helper.reindex(from: subtask.index_name_from, to: subtask.index_name_to,
          max_slice: slice.elastic_max_slice, slice: slice.elastic_slice, scroll: REINDEX_SCROLL)
        retry_attempt = slice.retry_attempt + 1

        logger.info(build_structured_payload(
          message: 'Retrying reindex task',
          retry_attempt: retry_attempt,
          task_id: task_id,
          index_from: subtask.index_name_from,
          index_to: subtask.index_name_to,
          slice: slice.elastic_slice))

        slice.update!(elastic_task: task_id, retry_attempt: retry_attempt)
      end

      def compare_documents_count
        current_task.subtasks.each do |subtask|
          old_documents_count = elastic_helper.documents_count(index_name: subtask.index_name_from, refresh: true)
          new_documents_count = elastic_helper.documents_count(index_name: subtask.index_name_to, refresh: true)
          next if old_documents_count == new_documents_count

          abort_reindexing!('Documents count is different. ' \
            'This likely means something went wrong during reindexing.',
            additional_logs: {
              document_count_from_new_index: new_documents_count,
              document_count_from_original_index: old_documents_count,
              index_from: subtask.index_name_from,
              index_to: subtask.index_name_to
            }
          )

          return false
        end

        # Update the database counts one final time for the UI.
        save_documents_count!(refresh: true)

        true
      end

      def trigger_reindexing_slices(slices_in_progress = 0)
        current_task.subtasks.each do |subtask|
          slices_to_start = current_task.max_slices_running - slices_in_progress
          break if slices_to_start == 0

          subtask.slices.not_started.limit(slices_to_start).each do |slice|
            task_id = elastic_helper.reindex(from: subtask.index_name_from, to: subtask.index_name_to,
              max_slice: slice.elastic_max_slice, slice: slice.elastic_slice, scroll: REINDEX_SCROLL)
            logger.info(build_structured_payload(
              message: 'Reindex task started',
              task_id: task_id,
              index_from: subtask.index_name_from,
              index_to: subtask.index_name_to,
              slice: slice.elastic_slice
            ))

            slice.update!(elastic_task: task_id)
            slices_in_progress += 1
          end
        end

        slices_in_progress
      end

      def apply_default_index_options
        current_task.subtasks.each do |subtask|
          elastic_helper.update_settings(
            index_name: subtask.index_name_to,
            settings: default_index_options(alias_name: subtask.alias_name, index_name: subtask.index_name_from)
          )
        end
      end

      def switch_alias_to_new_index
        actions = []

        current_task.subtasks.group_by(&:alias_name).each_value do |subtasks|
          subtasks.each_with_index do |subtask, index|
            # Pick the last index as the write one
            is_write_index = index == subtasks.length - 1
            actions += [
              {
                remove: { index: subtask.index_name_from, alias: subtask.alias_name }
              },
              {
                add: { index: subtask.index_name_to, alias: subtask.alias_name, is_write_index: is_write_index }
              }
            ]
          end
        end

        elastic_helper.multi_switch_alias(actions: actions)
      end

      def finalize_reindexing
        ::Gitlab::CurrentSettings.update!(elasticsearch_pause_indexing: false)

        current_task.update!(state: :success, delete_original_index_at: DELETE_ORIGINAL_INDEX_AFTER.from_now)
      end

      def reindexing!
        return false unless check_subtasks_and_reindex_slices
        return false unless compare_documents_count

        apply_default_index_options
        switch_alias_to_new_index
        finalize_reindexing

        true
      end

      def abort_reindexing!(reason, additional_logs: {}, unpause_indexing: true)
        logger.error(build_structured_payload(
          message: 'elasticsearch_reindex_error',
          error: reason,
          gitlab_task_id: current_task.id,
          gitlab_task_state: current_task.state,
          **additional_logs
        ))

        current_task.update!(state: :failure, error_message: reason)

        # Unpause indexing
        ::Gitlab::CurrentSettings.update!(elasticsearch_pause_indexing: false) if unpause_indexing
      end

      def logger
        @logger ||= ::Gitlab::Elasticsearch::Logger.build
      end

      def elastic_helper
        ::Gitlab::Elastic::Helper.default
      end
    end
  end
end
