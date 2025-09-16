# frozen_string_literal: true

module Search
  module ZoektSearchable
    include ::Gitlab::Utils::StrongMemoize

    def use_zoekt?
      # TODO: rename to search_code_with_zoekt?
      # https://gitlab.com/gitlab-org/gitlab/-/issues/421619
      return false if skip_api?
      return false unless ::Search::Zoekt.enabled_for_user?(current_user) && zoekt_searchable_scope?
      return false if Feature.enabled?(:disable_zoekt_search_for_saas, root_ancestor)

      zoekt_node_available_for_search?
    end

    def zoekt_searchable_scope
      raise NotImplementedError
    end

    def search_level
      raise NotImplementedError
    end

    def zoekt_searchable_scope?
      zoekt_searchable_scope.try(:search_code_with_zoekt?)
    end

    def root_ancestor
      zoekt_searchable_scope&.root_ancestor
    end

    def zoekt_projects
      @zoekt_projects ||= projects
    end

    def zoekt_filters
      params.slice(:language, :include_archived, :exclude_forks)
    end

    def zoekt_node_id
      zoekt_nodes.first&.id
    end
    strong_memoize_attr :zoekt_node_id

    def zoekt_nodes
      # Note: there will be more zoekt nodes whenever replicas are introduced.
      @zoekt_nodes ||= zoekt_searchable_scope.root_ancestor.zoekt_enabled_namespace.nodes
    end

    def zoekt_node_available_for_search?
      zoekt_nodes.exists?
    end

    def skip_api?
      return false unless params[:source] == 'api'
      return false if params[:search_type] == 'zoekt'

      Feature.disabled?(:zoekt_search_api, root_ancestor, type: :ops)
    end

    def zoekt_search_results
      ::Search::Zoekt::SearchResults.new(
        current_user,
        params[:search],
        zoekt_projects,
        search_level: search_level,
        source: params[:source],
        node_id: zoekt_node_id,
        order_by: params[:order_by],
        sort: params[:sort],
        multi_match_enabled: params[:multi_match_enabled],
        chunk_count: params[:chunk_count],
        filters: zoekt_filters,
        modes: { regex: params[:regex] }
      )
    end
  end
end
