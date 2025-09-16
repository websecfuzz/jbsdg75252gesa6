# frozen_string_literal: true

module Search
  module Zoekt
    class InfoService
      include ActionView::Helpers::NumberHelper
      include ActionView::Helpers::DateHelper

      def self.execute(...)
        new(...).execute
      end

      def initialize(logger:, options: {})
        @logger = logger
        @entries = []
        @options = options
      end

      def execute
        display_settings_section
        display_nodes_section
        display_indexing_status_section
        display_feature_flags_sections

        return unless options[:extended_mode]

        log_node_details
      end

      private

      attr_reader :logger, :entries, :options

      def display_feature_flags_sections
        log_header("Feature Flags (Non-Default Values)")
        log_custom_feature_flags
        display_entries

        log_header("Feature Flags (Default Values)")
        log_default_feature_flags
        display_entries
      end

      # Find and display all zoekt-related feature flags with custom values (non-default)
      def log_custom_feature_flags
        persisted_flags = Feature.persisted_names.select { |name| name.start_with?('zoekt_') }

        if persisted_flags.empty?
          log("Feature flags", value: Rainbow('none').yellow)
          return
        end

        # Get the state of each persisted flag
        flag_states = {}
        persisted_flags.each do |flag|
          # Skip flags without YAML definitions to avoid InvalidFeatureFlagError
          if Feature::Definition.has_definition?(flag.to_sym)
            enabled = Feature.enabled?(flag, Feature.current_request)
            state_text = enabled ? 'enabled' : 'disabled'
            state_color = enabled ? :green : :red
            flag_states[flag] = Rainbow(state_text).color(state_color)
          else
            # Mark flags without definitions
            flag_states[flag] = Rainbow('no definition').yellow
          end
        end

        # Sort flags alphabetically and log each flag and its state
        flag_states.sort.each do |flag, state|
          log("- #{flag}", value: state)
        end
      end

      # Display default feature flags section - shows all flags using default values
      def log_default_feature_flags
        # Get all zoekt-related feature flags that have YAML definitions
        all_flags = Feature::Definition.definitions.keys
        zoekt_flags = all_flags.select { |name| name.to_s.start_with?('zoekt_') }

        # Filter for only those using default values
        default_flags = zoekt_flags.reject { |flag| Feature.persisted_name?(flag.to_s) }

        if default_flags.empty?
          log("Feature flags", value: Rainbow('none').yellow)
          return
        end

        # Get the state of each default flag
        flag_states = {}
        default_flags.each do |flag|
          # Skip flags without YAML definitions to avoid errors
          next unless Feature::Definition.has_definition?(flag)

          enabled = Feature.enabled?(flag, Feature.current_request)
          state_text = enabled ? 'enabled' : 'disabled'
          state_color = enabled ? :green : :red
          flag_states[flag] = Rainbow(state_text).color(state_color)
        end

        # Sort flags alphabetically and log each flag and its state
        flag_states.sort_by { |k, _| k.to_s }.each do |flag, state|
          log("- #{flag}", value: state)
        end
      end

      # Display general settings section including GitLab version and Zoekt settings
      def display_settings_section
        setting = ::ApplicationSetting.current

        log_header("Exact Code Search")
        log("GitLab version", value: Gitlab.version_info)

        # Automatically log all Zoekt settings
        ::Search::Zoekt::Settings.all_settings.each do |setting_name, value|
          log(value[:label].call, value: setting.public_send(setting_name)) # rubocop:disable GitlabSecurity/PublicSend -- we control `setting_name` in source code
        end

        display_entries
      end

      def display_nodes_section
        log_header("Nodes")
        log_node_counts
        log_last_seen
        log('Max schema_version', value: Search::Zoekt::Node.maximum(:schema_version))
        log_indexed_data
        log_node_watermark_levels
        display_entries
      end

      def display_indexing_status_section
        log_header("Indexing status")
        log_enabled_namespaces
        log_model_counts
        display_entries
      end

      def log_node_counts
        total_count = Search::Zoekt::Node.count
        online_count = Search::Zoekt::Node.online.count
        offline_count = total_count - online_count
        log("Node count",
          value: "#{total_count} (online: #{Rainbow(online_count).green}, offline: #{Rainbow(offline_count).red})")
      end

      def log_node_watermark_levels
        nodes = Search::Zoekt::Node.online.to_a

        watermark_counts = Hash.new(0)

        nodes.each do |node|
          if node.watermark_exceeded_critical?
            watermark_counts[:critical] += 1
          elsif node.watermark_exceeded_high?
            watermark_counts[:high] += 1
          elsif node.watermark_exceeded_low?
            watermark_counts[:low] += 1
          else
            watermark_counts[:normal] += 1
          end
        end

        total = watermark_counts.values.sum
        if total > 0
          # Create a colored version of the watermark counts for display
          # We're not using color-coding here since it's being handled differently in display_nested_value
          colored_counts = watermark_counts.clone

          log("Online node watermark levels", value: total, nested: colored_counts)
        else
          log("Online node watermark levels", value: Rainbow('(none)').yellow)
        end
      end

      # rubocop: disable Metrics/AbcSize -- This method is quite straightforward.
      def log_node_details
        log_header("Node Details")

        # rubocop: disable CodeReuse/ActiveRecord -- temporary exemption in this rake task
        nodes = Search::Zoekt::Node.order(:id).to_a
        # rubocop: enable CodeReuse/ActiveRecord
        return if nodes.empty?

        max_schema_version = nodes.map(&:schema_version).max

        nodes.each do |node|
          # Get hostname from metadata
          hostname = node.metadata["name"] || Rainbow("unnamed").yellow

          # Determine online/offline status
          online = node.last_seen_at > Search::Zoekt::Node::ONLINE_DURATION_THRESHOLD.ago
          status = online ? Rainbow("Online").green : Rainbow("Offline").red

          # Format disk utilization percentage with appropriate color
          disk_percent = (node.storage_percent_used * 100).round(2)
          disk_percent_str = "#{disk_percent}%"
          disk_percent_colored = if node.watermark_exceeded_critical?
                                   Rainbow(disk_percent_str).red.bright
                                 elsif node.watermark_exceeded_high?
                                   Rainbow(disk_percent_str).red
                                 elsif node.watermark_exceeded_low?
                                   Rainbow(disk_percent_str).yellow
                                 else
                                   Rainbow(disk_percent_str).green
                                 end

          schema_version_colored = if node.schema_version != max_schema_version
                                     Rainbow(node.schema_version).yellow
                                   else
                                     node.schema_version
                                   end
          # Format unclaimed storage bytes
          unclaimed_bytes = number_to_human_size(node.unclaimed_storage_bytes)

          # Get version from metadata
          version = node.metadata["version"] || Rainbow("unknown").yellow

          # Format last_seen_at timestamp
          last_seen = node.last_seen_at.nil? ? Rainbow("(unknown)").yellow : format_value(node.last_seen_at)

          log("Node #{node.id} - #{hostname}", value: ' ')
          log("  Status", value: status)
          log("  Last seen at", value: last_seen)
          log("  Disk utilization", value: disk_percent_colored)
          log("  Unclaimed storage", value: unclaimed_bytes)
          log("  Zoekt version", value: version)
          log("  Schema version", value: schema_version_colored)
        end

        display_entries
      end
      # rubocop: enable Metrics/AbcSize

      def log_indexed_data
        usable_bytes = Search::Zoekt::Node.sum(:usable_storage_bytes)
        indexed_bytes = Search::Zoekt::Node.sum(:indexed_bytes)
        reserved_bytes = Search::Zoekt::Index.sum(:reserved_storage_bytes)
        used_bytes = Search::Zoekt::Node.sum(:used_bytes)
        total_bytes = Search::Zoekt::Node.sum(:total_bytes)

        # Calculate percentages with proper handling for zero values
        reserved_percentage = usable_bytes == 0 ? 0 : (reserved_bytes.to_f / usable_bytes * 100).round(2)
        indexed_percentage = reserved_bytes == 0 ? 0 : (indexed_bytes.to_f / reserved_bytes * 100).round(2)
        usage_percentage = total_bytes == 0 ? 0 : (used_bytes.to_f / total_bytes * 100).round(2)

        log("Storage reserved / usable", value: "#{number_to_human_size(reserved_bytes)} / " \
                                           "#{number_to_human_size(usable_bytes)} (#{reserved_percentage}%)")
        log("Storage indexed / reserved", value: "#{number_to_human_size(indexed_bytes)} / " \
                                            "#{number_to_human_size(reserved_bytes)} (#{indexed_percentage}%)")
        log("Storage used / total", value: "#{number_to_human_size(used_bytes)} / " \
                                      "#{number_to_human_size(total_bytes)} (#{usage_percentage}%)")
      end

      def log_last_seen
        log("Last seen at", value: Search::Zoekt::Node.maximum(:last_seen_at))
      end

      def log_enabled_namespaces
        group_count = Group.top_level.count
        log("Group count", value: group_count)

        total_count = Search::Zoekt::EnabledNamespace.count
        with_missing_indices = Search::Zoekt::EnabledNamespace.with_missing_indices.count
        with_search_disabled = Search::Zoekt::EnabledNamespace.search_disabled.count
        with_rollout_blocked = Search::Zoekt::EnabledNamespace.with_missing_indices.with_rollout_blocked.count
        log("EnabledNamespace count", value: "#{total_count} (without indices: #{Rainbow(with_missing_indices).red}, " \
                                        "rollout blocked: #{Rainbow(with_rollout_blocked).red}, " \
                                        "with search disabled: #{Rainbow(with_search_disabled).yellow})")
      end

      def log_model_counts
        log_model_count(Search::Zoekt::Replica, "Replicas count")
        log_model_count(Search::Zoekt::Index, "Indices count")
        log_model_count(Search::Zoekt::Index, "Indices watermark levels", group_by: :watermark_level)
        log_model_count(Search::Zoekt::Repository, "Repositories count")
        log_model_count(Search::Zoekt::Task.join_nodes, "Tasks count")
        log_model_count(Search::Zoekt::Task.join_nodes.pending_or_processing, "Tasks pending/processing by type",
          group_by: :task_type)
      end

      # rubocop:disable CodeReuse/ActiveRecord -- we need to use group(:state).count here without a scope
      def log_model_count(scope, label, group_by: :state)
        counts = scope.group(group_by).count
        log(label, value: counts.values.sum, nested: counts)
      end
      # rubocop:enable CodeReuse/ActiveRecord

      def format_value(value)
        case value
        when TrueClass
          Rainbow('yes').green
        when FalseClass
          'no'
        when ActiveSupport::TimeWithZone, Time
          utc_time = value.utc
          relative_time = time_ago_in_words(utc_time)
          "#{utc_time} (#{relative_time} ago)"
        when NilClass
          Rainbow('(never)').yellow
        else
          value.to_s
        end
      end

      def log_header(message)
        display_entries # Display any collected entries before the new header
        logger.info("\n#{Rainbow(message).bright.yellow.underline}")
        @entries = [] # Start a new section
      end

      def log(key, value: nil, nested: nil)
        entries << {
          key: key,
          value: value,
          nested: nested
        }
      end

      def display_entries
        return if entries.empty?

        # Calculate padding based only on current section's entries
        max_length = entries.map { |entry| entry[:key].length }.max
        padding = max_length + 2 # Add 2 for the colon and space

        entries.each do |entry|
          key_with_padding = "#{entry[:key]}:#{' ' * (padding - entry[:key].length)}"

          if entry[:nested]
            if entry[:nested].empty?
              logger.info("#{key_with_padding}#{Rainbow('(none)').yellow}")
            else
              logger.info("#{key_with_padding}#{entry[:value]}")
              display_nested_value(entry[:nested])
            end
          else
            formatted_value = format_value(entry[:value])
            logger.info("#{key_with_padding}#{formatted_value}")
          end
        end
        @entries = []
      end

      def display_nested_value(value, indent = 2)
        # Sort by key to ensure consistent order
        value.sort.each do |k, v|
          # For watermark levels and states, apply special coloring
          colored_value = case k.to_sym
                          when :critical, :failed, :critical_watermark_exceeded
                            Rainbow(v).red.bright
                          when :high, :evicted, :high_watermark_exceeded
                            Rainbow(v).red
                          when :low, :overprovisioned, :low_watermark_exceeded
                            Rainbow(v).yellow
                          when :normal, :done, :ready, :healthy
                            Rainbow(v).green
                          else
                            v
                          end

          logger.info("#{' ' * indent}- #{k}: #{colored_value}")
        end
      end
    end
  end
end
