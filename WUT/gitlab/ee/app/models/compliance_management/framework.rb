# frozen_string_literal: true

module ComplianceManagement
  class Framework < ApplicationRecord
    include StripAttribute
    include Gitlab::SQL::Pattern
    include EachBatch

    self.table_name = 'compliance_management_frameworks'

    strip_attributes! :name, :color

    belongs_to :namespace
    has_many :project_settings, class_name: 'ComplianceManagement::ComplianceFramework::ProjectSettings'
    has_many :projects, through: :project_settings

    has_many :compliance_framework_security_policies,
      class_name: 'ComplianceManagement::ComplianceFramework::SecurityPolicy'

    has_many :security_policies,
      class_name: 'Security::Policy',
      through: :compliance_framework_security_policies,
      source: :security_policy

    has_many :security_orchestration_policy_configurations,
      -> { distinct },
      class_name: 'Security::OrchestrationPolicyConfiguration',
      through: :compliance_framework_security_policies,
      source: :policy_configuration

    has_many :compliance_requirements, class_name: 'ComplianceManagement::ComplianceFramework::ComplianceRequirement'

    validates :namespace, presence: true
    validates :name, presence: true, length: { maximum: 255 }
    validates :description, presence: true, length: { maximum: 255 }
    validates :color, color: true, allow_blank: false, length: { maximum: 10 }
    validates :namespace_id, uniqueness: { scope: :name }
    validates :pipeline_configuration_full_path, length: { maximum: 255 }

    # Remove this validation once support for user namespaces is added.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/358423
    validate :namespace_is_root_level_group

    scope :with_projects, ->(project_ids) {
      includes(:projects)
      .where(projects: { id: project_ids })
      .ordered_by_addition_time_and_pipeline_existence
    }
    scope :with_namespaces, ->(namespace_ids) { includes(:namespace).where(namespaces: { id: namespace_ids }) }
    scope :ordered_by_addition_time_and_pipeline_existence, -> {
      left_joins(:project_settings)
        .order(
          Arel.sql('CASE WHEN pipeline_configuration_full_path IS NULL THEN 1 ELSE 0 END'),
          Arel.sql('project_compliance_framework_settings.created_at ASC NULLS LAST')
        )
    }

    scope :sorted_by_name_asc, -> { reorder(Framework.arel_table['name'].lower.asc) }
    scope :sorted_by_name_desc, -> { reorder(Framework.arel_table['name'].lower.desc) }
    scope :sorted_by_updated_at_asc, -> { reorder(Framework.arel_table['updated_at'].asc) }
    scope :sorted_by_updated_at_desc, -> { reorder(Framework.arel_table['updated_at'].desc) }

    # Returns frameworks that need attention: no projects, no requirements, or requirements without controls
    scope :needing_attention_for_group, ->(group) {
      projects_in_hierarchy = group.all_project_ids

      from(
        sanitize_sql([
          "(
           SELECT
             cmf.*,
             COALESCE(counts.projects_count, 0) AS projects_count,
             COALESCE(counts.requirements_count, 0) AS requirements_count,
             COALESCE(counts.requirements_without_controls_count, 0) AS requirements_without_controls_count
           FROM compliance_management_frameworks cmf
           LEFT JOIN (
             -- Subquery to calculate all counts for each framework
             SELECT
               f.id as framework_id,

               -- Count projects using this framework within the group hierarchy
               COALESCE((
                 SELECT COUNT(*)
                 FROM project_compliance_framework_settings pfs
                 WHERE pfs.framework_id = f.id
                 AND pfs.project_id IN (?)
               ), 0) AS projects_count,

               -- Count total requirements for this framework
               COALESCE((
                 SELECT COUNT(*)
                 FROM compliance_requirements cr
                 WHERE cr.framework_id = f.id
               ), 0) AS requirements_count,

               -- Count requirements that have no associated controls
               -- (LEFT JOIN with NULL check finds unmatched requirements)
               COALESCE((
                 SELECT COUNT(*)
                 FROM compliance_requirements cr
                 LEFT JOIN compliance_requirements_controls crc ON cr.id = crc.compliance_requirement_id
                 WHERE cr.framework_id = f.id AND crc.id IS NULL
               ), 0) AS requirements_without_controls_count

             FROM compliance_management_frameworks f
           ) counts ON cmf.id = counts.framework_id

           -- Only include frameworks belonging to the root namespace
           WHERE cmf.namespace_id = ?
         ) AS compliance_management_frameworks",
          projects_in_hierarchy.any? ? projects_in_hierarchy : [0],
          group.root_ancestor.id
        ])
      )
        .where(
          "projects_count = 0 OR requirements_count = 0 OR requirements_without_controls_count > 0"
        )
    }

    scope :with_requirements_and_controls, -> {
      joins(compliance_requirements: :compliance_requirements_controls)
        .includes(compliance_requirements: :compliance_requirements_controls)
    }

    scope :with_project_settings, -> {
      joins(:project_settings)
        .includes(project_settings: :project)
    }

    scope :with_active_controls, -> {
      with_requirements_and_controls
        .with_project_settings
        .distinct
    }

    scope :with_project_coverage_for, ->(project_ids) do
      return none if project_ids.blank?

      subquery_sql = <<~SQL.squish
        COALESCE((
          SELECT COUNT(DISTINCT project_id)
          FROM project_compliance_framework_settings
          WHERE framework_id = compliance_management_frameworks.id
          AND project_id IN (?)
        ), 0) AS covered_count
      SQL

      select('*', sanitize_sql_array([subquery_sql, project_ids]))
    end

    def self.search(query)
      query.present? ? fuzzy_search(query, [:name], use_minimum_char_limit: true) : all
    end

    def self.sort_by_attribute(method)
      case method.to_s
      when 'name_asc' then sorted_by_name_asc
      when 'name_desc' then sorted_by_name_desc
      when 'updated_at_asc' then sorted_by_updated_at_asc
      else
        sorted_by_updated_at_desc
      end
    end

    def filename = "compliance-framework-#{name.parameterize}-#{id}"

    def approval_settings_from_security_policies(projects)
      ::Security::ScanResultPolicyRead
        .for_project(projects)
        .for_policy_configuration(security_orchestration_policy_configurations)
        .map(&:project_approval_settings)
    end

    private

    def namespace_is_root_level_group
      return unless namespace

      errors.add(:namespace, 'must be a group, user namespaces are not supported.') unless namespace.group_namespace?
      errors.add(:namespace, 'must be a root group.') if namespace.has_parent?
    end
  end
end
