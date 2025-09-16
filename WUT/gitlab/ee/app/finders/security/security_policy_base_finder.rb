# frozen_string_literal: true

module Security
  class SecurityPolicyBaseFinder
    def initialize(actor, object, policy_type, params)
      @actor = actor
      @object = object
      @policy_type = policy_type
      @params = params
    end

    def execute
      fetch_security_policies
    end

    private

    attr_reader :actor, :object, :policy_type, :params

    def fetch_security_policies
      return [] unless authorized_to_read_policy_configuration?

      fetch_policy_configurations
        .flat_map { |config| merge_project_relationship(config) }
    end

    def policy_configuration
      @policy_configuration ||= object.security_orchestration_policy_configuration
    end

    def authorized_to_read_policy_configuration?
      Ability.allowed?(actor, :read_security_orchestration_policies, object)
    end

    def fetch_policy_configurations
      case params[:relationship]
      when :inherited
        object.all_security_orchestration_policy_configurations(include_invalid: true)
      when :inherited_only
        object.all_inherited_security_orchestration_policy_configurations(include_invalid: true)
      when :descendant
        descendant_policy_configurations
      else
        default_policy_configurations
      end
    end

    def descendant_policy_configurations
      return default_policy_configurations if object.is_a?(Project)

      object.all_descendant_security_orchestration_policy_configurations
    end

    def default_policy_configurations
      return Array.wrap(policy_configuration) if params[:include_invalid]

      Array.wrap(policy_configuration).select { |config| config&.policy_configuration_valid? }
    end

    def merge_project_relationship(config)
      return [] unless config.respond_to? policy_type

      policies(config).filter_map do |policy|
        next if !params[:include_unscoped] && !policy_scope_applicable?(policy)

        policy.merge(
          config: config,
          project: config.project,
          namespace: config.namespace,
          inherited: config.source != object,
          csp: config.designated_as_csp?
        )
      end
    end

    def policies(config)
      case policy_type
      when :pipeline_execution_policy
        config.pipeline_execution_policy
      when :pipeline_execution_schedule_policy
        config.pipeline_execution_schedule_policy
      when :scan_execution_policy
        config.scan_execution_policy
      when :scan_result_policies
        config.scan_result_policies
      when :vulnerability_management_policy
        config.vulnerability_management_policy
      when :all_policies
        all_policies_with_type(config)
      end
    end

    def all_policies_with_type(config)
      return [] unless Feature.enabled?(:security_policies_combined_list, object)

      policies_with_type = config.all_policies_with_type
      return policies_with_type if params[:type].blank?

      policies_with_type.select { |policy| policy[:type] == params[:type].to_s }
    end

    def policy_scope_applicable?(policy)
      return true unless object.is_a?(Project)

      policy_scope_checker = Security::SecurityOrchestrationPolicies::PolicyScopeChecker.new(project: object)
      policy_scope_checker.policy_applicable?(policy)
    end
  end
end
