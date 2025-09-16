# frozen_string_literal: true

module Security
  class OrchestrationPolicyConfiguration < ApplicationRecord
    include Gitlab::Git::WrapsGitalyErrors
    include Security::ScanExecutionPolicy
    include Security::ScanResultPolicy
    include Security::PipelineExecutionPolicy
    include Security::PipelineExecutionSchedulePolicy
    include Security::CiComponentPublishingPolicy
    include Security::VulnerabilityManagementPolicy
    include EachBatch
    include Gitlab::Utils::StrongMemoize
    include FromUnion

    self.table_name = 'security_orchestration_policy_configurations'

    ignore_column :bot_user_id, remove_with: '16.7', remove_after: '2023-11-22'

    CACHE_DURATION = 1.hour
    POLICY_PATH = '.gitlab/security-policies/policy.yml'
    POLICY_SCHEMA_PATH = 'ee/app/validators/json_schemas/security_orchestration_policy.json'
    POLICY_SCHEMA = JSONSchemer.schema(Rails.root.join(POLICY_SCHEMA_PATH))
    # json_schemer computes an $id fallback property for schemas lacking one.
    # But this schema is kept anonymous on purpose, so the $id is stripped.
    POLICY_SCHEMA_JSON = POLICY_SCHEMA.value.except('$id')
    AVAILABLE_POLICY_TYPES = %i[approval_policy scan_execution_policy pipeline_execution_policy pipeline_execution_schedule_policy vulnerability_management_policy ci_component_publishing_policy].freeze
    JSON_SCHEMA_VALIDATION_TIMEOUT = 5.seconds
    ALL_PROJECT_IDS_BATCH_SIZE = 1000

    belongs_to :project, inverse_of: :security_orchestration_policy_configuration, optional: true
    belongs_to :namespace, inverse_of: :security_orchestration_policy_configuration, optional: true
    belongs_to :security_policy_management_project, class_name: 'Project', foreign_key: 'security_policy_management_project_id'
    has_many :security_policies, class_name: 'Security::Policy', foreign_key: 'security_orchestration_policy_configuration_id'

    has_many :compliance_framework_security_policies,
      class_name: 'ComplianceManagement::ComplianceFramework::SecurityPolicy',
      foreign_key: :policy_configuration_id

    validates :project, uniqueness: true, if: :project
    validates :project, presence: true, unless: :namespace
    validates :namespace, uniqueness: true, if: :namespace
    validates :namespace, presence: true, unless: :project
    validates :security_policy_management_project, presence: true
    validates :experiments, json_schema: { filename: 'security_policy_experiments' }, allow_blank: true

    scope :for_project, ->(project_id) { where(project_id: project_id) }
    scope :for_namespace, ->(namespace_id) { where(namespace_id: namespace_id) }
    scope :with_project_and_namespace, -> { includes(:project, :namespace) }
    scope :for_management_project, ->(management_project_id) { where(security_policy_management_project_id: management_project_id) }
    scope :with_security_policies, -> { includes(:security_policies) }
    scope :with_outdated_configuration, -> do
      joins(:security_policy_management_project)
        .where(arel_table[:configured_at].lt(Project.arel_table[:last_repository_updated_at]).or(arel_table[:configured_at].eq(nil)))
    end
    scope :for_management_project_within_descendants, ->(management_project_id, group) do
      groups = group.descendants
      projects = group.all_projects

      from_union([for_namespace(groups.select(:id)), for_project(projects.select(:id))])
        .merge(for_management_project(management_project_id))
    end

    scope :for_namespace_and_projects, ->(namespace_ids, project_ids) do
      for_namespace(namespace_ids).or(for_project(project_ids))
    end

    delegate :actual_limits, :actual_plan_name, :actual_plan, :designated_as_csp?, to: :source

    def self.policy_management_project?(project_id)
      self.exists?(security_policy_management_project_id: project_id)
    end

    def policy_hash
      Rails.cache.fetch(policy_cache_key, expires_in: CACHE_DURATION) do
        policy_yaml
      end
    end

    def invalidate_policy_yaml_cache
      Rails.cache.delete(policy_cache_key)
    end

    def policy_configuration_exists?
      policy_hash.present?
    end

    def policy_configuration_valid?(policy = policy_hash)
      Timeout.timeout(JSON_SCHEMA_VALIDATION_TIMEOUT) do
        POLICY_SCHEMA.valid?(policy.to_h.deep_stringify_keys)
      end
    end

    def policy_configuration_validation_errors(policy = policy_hash)
      Timeout.timeout(JSON_SCHEMA_VALIDATION_TIMEOUT) do
        POLICY_SCHEMA
          .validate(policy.to_h.deep_stringify_keys)
          .map { |error| JSONSchemer::Errors.pretty(error) }
      end
    end

    def policy_last_updated_by
      strong_memoize(:policy_last_updated_by) do
        last_merge_request&.author
      end
    end

    def policy_last_updated_at
      strong_memoize(:policy_last_updated_at) do
        capture_git_error(:last_commit_for_path) do
          policy_repo.last_commit_for_path(default_branch_or_main, POLICY_PATH)&.committed_date
        end
      end
    end

    def latest_commit_before_configured_at
      return if configured_at.nil?

      capture_git_error(:commits) do
        policy_repo.commits(
          default_branch_or_main,
          before: configured_at,
          limit: 1
        ).first
      end
    end
    strong_memoize_attr :latest_commit_before_configured_at

    def policy_limit_by_type(policy_type)
      validate_policy_type(policy_type)

      case policy_type.to_sym
      when :approval_policy
        approval_policies_limit
      when :pipeline_execution_policy
        pipeline_execution_policy_limit
      when :scan_execution_policy
        ScanExecutionPolicy::POLICY_LIMIT
      when :pipeline_execution_schedule_policy
        PipelineExecutionSchedulePolicy::POLICY_LIMIT
      when :vulnerability_management_policy
        VulnerabilityManagementPolicy::POLICY_LIMIT
      when :ci_component_publishing_policy
        CiComponentPublishingPolicy::POLICY_LIMIT
      end
    end

    def policy_type_name_by_type(policy_type)
      validate_policy_type(policy_type)

      case policy_type.to_sym
      when :approval_policy
        ScanResultPolicy::POLICY_TYPE_NAME
      when :scan_execution_policy
        ScanExecutionPolicy::POLICY_TYPE_NAME
      when :pipeline_execution_policy
        PipelineExecutionPolicy::POLICY_TYPE_NAME
      when :pipeline_execution_schedule_policy
        PipelineExecutionSchedulePolicy::POLICY_TYPE_NAME
      when :vulnerability_management_policy
        VulnerabilityManagementPolicy::POLICY_TYPE_NAME
      when :ci_component_publishing_policy
        CiComponentPublishingPolicy::POLICY_TYPE_NAME
      end
    end

    def policy_by_type(type_or_types)
      return [] if policy_hash.blank?

      policy_hash.values_at(*Array.wrap(type_or_types).map(&:to_sym)).flatten.compact
    end

    def default_branch_or_main
      security_policy_management_project.default_branch_or_main
    end

    def project?
      !namespace?
    end

    def namespace?
      namespace_id.present?
    end

    def source
      project || namespace
    end

    def compliance_framework_ids_with_policy_index
      return [] if project?

      all_policies
        .map
        .with_index do |policy, index|
          framework_ids = policy.dig(:policy_scope, :compliance_frameworks)&.pluck(:id)
          { framework_ids: framework_ids, policy_index: index } if framework_ids
        end.compact
    end

    def all_policies
      scan_result_policies +
        scan_execution_policy +
        pipeline_execution_policy +
        vulnerability_management_policy
    end

    def all_policies_with_type
      return [] if policy_hash.blank?

      policy_hash.flat_map do |type, policies|
        next if available_policy_types.exclude?(type)

        policies.map do |policy|
          policy.merge(type: type.to_s)
        end
      end.compact_blank
    end

    def policies_changed?
      yaml_differs_from_db?(security_policies.type_approval_policy, scan_result_policies) ||
        yaml_differs_from_db?(security_policies.type_scan_execution_policy, scan_execution_policy) ||
        yaml_differs_from_db?(security_policies.type_pipeline_execution_policy, pipeline_execution_policy) ||
        yaml_differs_from_db?(security_policies.type_pipeline_execution_schedule_policy, pipeline_execution_schedule_policy) ||
        yaml_differs_from_db?(security_policies.type_vulnerability_management_policy, vulnerability_management_policy)
    end

    def policy_changes(db_policies, yaml_policies)
      db_policies_with_checksums = db_policies.index_by(&:checksum)
      db_policies_with_names = db_policies.index_by(&:name)

      deleted_policies = db_policies_with_checksums.values
      new_policies = []
      policies_changes = []
      rearranged_policies = []

      yaml_policies.each_with_index do |policy_hash, index|
        checksum = Security::Policy.checksum(policy_hash)
        db_policy = db_policies_with_checksums[checksum] || db_policies_with_names[policy_hash[:name]]

        next new_policies << [policy_hash, index] unless db_policy

        deleted_policies.delete(db_policy)

        if db_policy.checksum != checksum
          policies_changes << Security::SecurityOrchestrationPolicies::PolicyComparer.new(
            db_policy: db_policy, yaml_policy: policy_hash, policy_index: index
          )
        end

        rearranged_policies << [db_policy, index] if db_policy.policy_index != index
      end

      [new_policies, deleted_policies, policies_changes, rearranged_policies]
    end

    def all_project_ids(&block)
      if project?
        yield Array.wrap(project_id)
      else
        collect_all_project_ids_in_batches(&block)
      end
    end

    def self_and_ancestor_configuration_ids
      if project?
        [*group_configurations_ids(project.namespace), id]
      else
        group_configurations_ids(namespace)
      end
    end

    def enabled_experiments
      return [] if experiments.blank?

      experiments
        .select { |_experiment, values| values['enabled'] == true }
        .keys
    end

    def experiment_enabled?(experimental_feature_name)
      return false if experiments.blank?

      experiments.dig(experimental_feature_name.to_s, 'enabled') == true
    end

    def experiment_configuration(experimental_feature_name)
      return {} if experiments.blank?

      experiments.dig(experimental_feature_name.to_s, 'configuration') || {}
    end

    def first_configuration_for_the_management_project?
      self.class.for_management_project(security_policy_management_project_id)
      .where(self.class.arel_table[:created_at].lt(created_at))
      .none?
    end

    private

    def validate_policy_type(policy_type)
      return if AVAILABLE_POLICY_TYPES.include?(policy_type.to_sym)

      raise ArgumentError, "Invalid policy type: #{policy_type}"
    end

    def available_policy_types
      policies_to_exclude = experiment_enabled?(:pipeline_execution_schedule_policy) ? [] : [:pipeline_execution_schedule_policy]

      AVAILABLE_POLICY_TYPES - policies_to_exclude
    end

    def yaml_differs_from_db?(policies_persisted_in_database, policies_in_policy_yaml)
      policy_changes(policies_persisted_in_database.undeleted, policies_in_policy_yaml).any?(&:present?)
    end

    def policy_cache_key
      "security_orchestration_policy_configurations:#{id}:policy_yaml"
    end

    def policy_yaml
      return if policy_blob.blank?

      Gitlab::Config::Loader::Yaml.new(policy_blob).load!
    rescue Gitlab::Config::Loader::FormatError
      nil
    end

    def policy_repo
      security_policy_management_project.repository
    end

    def policy_blob
      strong_memoize(:policy_blob) do
        capture_git_error(:blob_data_at) do
          policy_repo.blob_data_at(default_branch_or_main, POLICY_PATH)
        end
      end
    end

    def last_merge_request
      security_policy_management_project.merge_requests.merged.order_merged_at_desc.first
    end

    def capture_git_error(action, &block)
      wrapped_gitaly_errors(&block)
    rescue Gitlab::Git::BaseError => e

      Gitlab::ErrorTracking.log_exception(e, action: action, security_orchestration_policy_configuration_id: id)

      nil
    end

    def group_configurations_ids(group)
      parent_group_ids = group.self_and_ancestor_ids_with_csp
      self.class.for_namespace(parent_group_ids).pluck_primary_key
    end

    def collect_all_project_ids_in_batches(&block)
      if namespace.designated_as_csp?
        collect_csp_project_ids_in_batches(&block)
      else
        collect_namespace_project_ids_in_batches(&block)
      end
    end

    def collect_csp_project_ids_in_batches
      namespace.all_project_ids_with_csp_in_batches(of: ALL_PROJECT_IDS_BATCH_SIZE) do |batch|
        yield batch.pluck_primary_key
      end
    end

    def collect_namespace_project_ids_in_batches
      cursor = { current_id: namespace_id, depth: [namespace_id] }
      iterator = ::Gitlab::Database::NamespaceEachBatch.new(namespace_class: Namespace, cursor: cursor)

      iterator.each_batch(of: ALL_PROJECT_IDS_BATCH_SIZE) do |ids|
        namespace_ids = Namespaces::ProjectNamespace.where(id: ids)
        # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- IDs will not be used in IN queries
        ids = Project.where(project_namespace_id: namespace_ids).pluck(:id)
        yield ids if ids.present?
        # rubocop: enable Database/AvoidUsingPluckWithoutLimit
      end
    end
  end
end
