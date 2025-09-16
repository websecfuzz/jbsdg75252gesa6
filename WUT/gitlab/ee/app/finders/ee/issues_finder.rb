# frozen_string_literal: true

module EE
  module IssuesFinder
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    class_methods do
      extend ::Gitlab::Utils::Override

      override :scalar_params
      def scalar_params
        @scalar_params ||= super + [:weight, :epic_id, :include_subepics, :iteration_id, :iteration_title]
      end

      override :array_params
      def array_params
        @array_params ||= super.merge({ custom_field: {} })
      end

      override :negatable_params
      def negatable_params
        @negatable_params ||= super + [:iteration_title, :weight]
      end
    end

    override :filter_items
    def filter_items(items)
      issues = by_weight(super)
      issues = by_epic(issues)
      issues = by_iteration(issues)
      issues = by_iteration_cadence(issues)
      issues = by_custom_field(issues)
      issues = by_status(issues)
      by_health_status(issues)
    end

    private

    # rubocop: disable CodeReuse/ActiveRecord
    def by_weight(items)
      return items unless params.weights?

      if params.filter_by_no_weight?
        items.where(weight: [-1, nil])
      elsif params.filter_by_any_weight?
        items.where.not(weight: [-1, nil])
      else
        items.where(weight: params[:weight])
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def by_epic(items)
      return items unless params.by_epic?

      if params.filter_by_no_epic?
        items.no_epic
      elsif params.filter_by_any_epic?
        items.any_epic
      else
        items.in_epics(params.epics)
      end
    end

    def by_iteration(items)
      return items unless params.by_iteration?

      if params.filter_by_no_iteration?
        items.no_iteration
      elsif params.filter_by_any_iteration?
        items.any_iteration
      elsif params.filter_by_current_iteration? && get_current_iteration
        items.in_iteration_scope(get_current_iteration)
      elsif params.filter_by_iteration_title?
        items.with_iteration_title(params[:iteration_title])
      else
        items.in_iterations(params[:iteration_id])
      end
    end

    def by_iteration_cadence(items)
      return items unless params.by_iteration_cadence?

      items.in_iteration_cadences(params.iteration_cadence_id)
    end

    def by_custom_field(items)
      ::WorkItems::CustomFieldFilter.new(
        params: original_params,
        parent: params.parent
      ).filter(items)
    end

    def by_status(items)
      ::WorkItems::StatusFilter.new(
        params: original_params,
        parent: params.parent
      ).filter(items)
    end

    def by_health_status(items)
      return items unless params.by_health_status?

      if params.filter_by_no_health_status?
        items.with_no_health_status
      elsif params.filter_by_any_health_status?
        items.with_any_health_status
      else
        items.with_health_status(params[:health_status])
      end
    end

    override :filter_negated_items
    def filter_negated_items(items)
      items = by_negated_epic(items)
      items = by_negated_iteration(items)
      items = by_negated_weight(items)
      items = by_negated_health_status(items)

      super
    end

    def by_negated_weight(items)
      return items unless not_params[:weight].present?

      items.without_weights(not_params[:weight])
    end

    def by_negated_epic(items)
      return items unless not_params[:epic_id].present?

      items.not_in_epics(not_params[:epic_id].to_i)
    end

    def by_negated_health_status(items)
      return items unless not_params[:health_status_filter].present?

      items.without_health_status(not_params[:health_status_filter])
    end

    def by_negated_iteration(items)
      return items unless not_params.by_iteration?

      if not_params.filter_by_current_iteration?
        items.not_in_iterations(get_current_iteration)
      elsif not_params.filter_by_iteration_title?
        items.without_iteration_title(not_params[:iteration_title])
      else
        items.not_in_iterations(not_params[:iteration_id])
      end
    end

    def get_current_iteration
      return unless params.parent

      IterationsFinder.new(current_user, iterations_finder_params).execute
    end
    strong_memoize_attr :get_current_iteration

    def iterations_finder_params
      {
        parent: params.parent,
        include_ancestors: true,
        iteration_wildcard_id: ::Iteration::Predefined::Current.title
      }
    end
  end
end
