# frozen_string_literal: true

class AutoMergeService < BaseService
  include Gitlab::Utils::StrongMemoize

  STRATEGY_MERGE_WHEN_CHECKS_PASS = 'merge_when_checks_pass'
  # Only used in EE
  STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_CHECKS_PASS = 'add_to_merge_train_when_checks_pass'
  STRATEGIES = [STRATEGY_MERGE_WHEN_CHECKS_PASS].freeze

  class << self
    def all_strategies_ordered_by_preference
      STRATEGIES
    end

    def get_service_class(strategy)
      return unless all_strategies_ordered_by_preference.include?(strategy)

      strategy_to_class_map[strategy]
    end

    def strategy_to_class_map
      {
        STRATEGY_MERGE_WHEN_CHECKS_PASS => AutoMerge::MergeWhenChecksPassService
      }
    end
  end

  def execute(merge_request, strategy = nil)
    strategy ||= preferred_strategy(merge_request)
    instance = auto_merge_service_instance(merge_request, strategy)

    return :failed unless instance&.available_for?(merge_request)

    instance.execute(merge_request)
  end

  def update(merge_request)
    return :failed unless merge_request.auto_merge_enabled?

    perform_method(merge_request) do |instance|
      instance.update(merge_request)
    end
  end

  def process(merge_request)
    return unless merge_request.auto_merge_enabled?

    perform_method(merge_request) do |instance|
      instance.process(merge_request)
    end
  end

  def cancel(merge_request)
    return error("Can't cancel the automatic merge", 406) unless merge_request.auto_merge_enabled?

    perform_method(merge_request) do |instance|
      instance.cancel(merge_request)
    end
  end

  def abort(merge_request, reason)
    return error("Can't abort the automatic merge", 406) unless merge_request.auto_merge_enabled?

    perform_method(merge_request) do |instance|
      instance.abort(merge_request, reason)
    end
  end

  def available_strategies(merge_request)
    self.class.all_strategies_ordered_by_preference.select do |strategy|
      auto_merge_service_instance(merge_request, strategy).available_for?(merge_request)
    end
  end

  def preferred_strategy(merge_request)
    available_strategies(merge_request).first
  end

  private

  def auto_merge_service_instance(merge_request, strategy)
    strong_memoize_with(:auto_merge_service_instance, merge_request, strategy) do
      self.class.get_service_class(strategy)&.new(project, current_user, params)
    end
  end

  def perform_method(merge_request)
    strategy = merge_request.auto_merge_strategy
    instance = auto_merge_service_instance(merge_request, strategy)

    if instance.present?
      yield(instance)
    else
      AutoMerge::BaseService.new(project, current_user, params).cancel(merge_request)
    end
  end
end

AutoMergeService.prepend_mod_with('AutoMergeService')
