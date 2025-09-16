# frozen_string_literal: true

module Sbom
  class PathFinder
    include Gitlab::Utils::StrongMemoize

    attr_reader :occurrence, :after_graph_ids, :before_graph_ids, :limit
    attr_accessor :mode, :collector

    def self.execute(sbom_occurrence, after_graph_ids: [], before_graph_ids: [], limit: 20)
      new(sbom_occurrence, after_graph_ids: after_graph_ids, before_graph_ids: before_graph_ids, limit: limit).execute
    end

    def initialize(sbom_occurrence, after_graph_ids:, before_graph_ids:, limit:)
      @occurrence = sbom_occurrence
      @after_graph_ids = after_graph_ids || []
      @before_graph_ids = before_graph_ids || []
      @limit = limit || 20
    end

    def execute
      result = Gitlab::Metrics.measure(:build_dependency_paths) do
        project_id = occurrence.project_id
        target_id = occurrence.id

        parents = build_parent_mapping(project_id)
        paths_data = find_all_id_paths(target_id, parents)
        occurrence_paths = convert_id_paths_to_occurrences(paths_data[:paths])

        {
          paths: occurrence_paths,
          has_previous_page: paths_data[:has_previous_page],
          has_next_page: paths_data[:has_next_page]
        }
      end

      record_metrics(result[:paths])
      result
    end

    private

    def build_parent_mapping(project_id)
      parents = {}

      Sbom::GraphPath
        .adjacency_matrix_for_project_and_timestamp(project_id, latest_timestamp)
        .each_batch(of: 1000) do |batch|
        batch.each do |path|
          parents[path.descendant_id] ||= []
          parents[path.descendant_id] << path.ancestor_id
        end
      end

      parents
    end

    def latest_timestamp
      Sbom::GraphPath.by_projects(occurrence.project_id).maximum(:created_at)
    end
    strong_memoize_attr :latest_timestamp

    def find_all_id_paths(target_id, parents)
      root_nodes = find_root_nodes(parents)

      @mode = if before_graph_ids.blank? && after_graph_ids.blank?
                :unscoped
              elsif before_graph_ids.any?
                :before
              else
                :after
              end

      collect_paths(root_nodes, target_id, parents)
    end

    def find_root_nodes(parents)
      # Get all nodes mentioned in the graph
      all_nodes = Set.new

      parents.each do |child, parent_list|
        all_nodes.add(child)
        parent_list.each { |parent| all_nodes.add(parent) }
      end

      # Nodes that aren't children of any other node are roots
      root_nodes = all_nodes.select do |node|
        !parents.key?(node) || parents[node].empty?
      end

      # Sort root nodes for deterministic traversal order
      root_nodes.sort
    end

    def collect_paths(root_nodes, target_id, parents)
      @collector = create_collector

      root_nodes.each do |root_id|
        break unless should_continue_traversal?

        traverse_graph(root_id, target_id, parents, [], Set.new)
      end

      if should_add_top_level_path?(@collector[:paths], occurrence)
        @collector[:paths].prepend({ path: [target_id], is_cyclic: false })
      end

      if @mode == :before
        has_previous_page = @collector[:paths].length > limit
        has_next_page = true
        paths = @collector[:paths].last(limit)
      else
        has_previous_page = @mode == :after
        has_next_page = @collector[:paths].length > limit
        paths = @collector[:paths].first(limit)
      end

      paths = [{ path: [target_id], is_cyclic: false }] if paths.empty? && @mode == :unscoped

      {
        paths: paths,
        has_previous_page: has_previous_page,
        has_next_page: has_next_page
      }
    end

    def create_collector
      {
        paths: [],
        cursor_found: false
      }
    end

    def traverse_graph(current, target, parents, path_so_far, visited)
      current_path = path_so_far + [current]

      return if should_prune_branch?(current_path)

      return if handle_cursor_path(current_path)

      # If we've reached the target, we have a complete path
      if current == target
        handle_target_reached(current_path, false)
        return
      end

      # Skip if we've already visited this node on this path to avoid cycles
      return if visited.include?(current)

      # Early termination checks
      return unless should_continue_traversal?

      # Continue traversal
      visited_for_branch = visited.clone.add(current)
      children = find_children(current, parents)

      children.each do |child|
        break unless should_continue_traversal?

        traverse_graph(child, target, parents, current_path, visited_for_branch)
      end
    end

    # Checks if the current_path should be pruned based on after cursor.
    # In :after mode if a branch does not contain a path that is lexicographically equal or greater to after_graph_ids,
    # it should be pruned
    def should_prune_branch?(current_path)
      return false unless @mode == :after

      min_length = [current_path.length, after_graph_ids.length].min

      (0...min_length).each do |i|
        diff = current_path[i] <=> after_graph_ids[i]
        return true if diff < 0
        return false if diff > 0
      end

      # All compared elements are equal - don't prune as we might find the cursor or paths after it
      false
    end

    def handle_cursor_path(current_path)
      cursor_path = @mode == :after ? after_graph_ids : before_graph_ids

      if cursor_path.any? && paths_equal?(current_path, cursor_path)
        @collector[:cursor_found] = true
        true
      else
        false
      end
    end

    def handle_target_reached(current_path, is_cyclic)
      path_entry = { path: current_path, is_cyclic: is_cyclic }

      # Add path based on mode and cursor status
      if @mode == :unscoped ||
          (@mode == :after && @collector[:cursor_found]) ||
          (@mode == :before && !@collector[:cursor_found])
        add_path_to_collector(path_entry)
      end
    end

    def add_path_to_collector(path_entry)
      if @mode == :before
        # Sliding window: keep only last limit+1 paths
        @collector[:paths] << path_entry
        @collector[:paths].shift if @collector[:paths].length > limit + 1
      else
        @collector[:paths] << path_entry
      end
    end

    def should_continue_traversal?
      if @mode == :before
        !@collector[:cursor_found]
      else
        @collector[:paths].length <= limit
      end
    end

    def paths_equal?(path1, path2)
      return false if path1.length != path2.length

      path1.each_with_index.all? { |node, i| node == path2[i] }
    end

    def find_children(current, parents)
      children = []
      parents.each do |child, parent_list|
        children << child if parent_list.include?(current)
      end
      # Sort children for deterministic traversal order
      children.sort
    end

    def convert_id_paths_to_occurrences(id_paths)
      all_ids = id_paths.flat_map { |item| item[:path] }.uniq
      occurrence_map = build_occurrence_map(all_ids)

      # Convert ID paths to occurrence paths, preserving cycle information
      id_paths.map do |item|
        {
          path: item[:path].map { |id| occurrence_map[id] },
          is_cyclic: item[:is_cyclic]
        }
      end
    end

    def build_occurrence_map(ids)
      occurrence_map = {}

      Sbom::Occurrence.id_in(ids).with_version.each_batch(of: 1000) do |batch|
        batch.each do |occurrence|
          occurrence_map[occurrence.id] = occurrence
        end
      end

      occurrence_map
    end

    # Add the self reference path if the target is top level and we are in unscoped mode.
    # If the path is already in the list, we skip adding it.
    # We add the self reference path at the front rather than at the end.
    # This is done to preserve pagination.
    def should_add_top_level_path?(paths, target_occurrence)
      return false unless target_occurrence.top_level? && @mode == :unscoped

      has_self_path = paths.any? do |p|
        p[:path].length == 1 && p[:path][0] == target_occurrence.id
      end

      !has_self_path
    end

    def record_metrics(paths)
      counter = Gitlab::Metrics.counter(
        :dependency_paths_found,
        'Count of Dependency Paths found'
      )

      counter.increment(
        { cyclic: false },
        paths.count { |r| !r[:is_cyclic] }
      )
      counter.increment(
        { cyclic: true },
        paths.count { |r| r[:is_cyclic] }
      )
    end
  end
end
