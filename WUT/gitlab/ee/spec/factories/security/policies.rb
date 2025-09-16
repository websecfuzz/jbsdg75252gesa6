# frozen_string_literal: true

FactoryBot.define do
  FactoryBot.define do
    trait :with_policy_scope do
      policy_scope do
        {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ],
          projects: {
            including: [
              { id: 1 }
            ],
            excluding: [
              { id: 2 }
            ]
          }
        }
      end
    end
  end

  factory :security_policy, class: 'Security::Policy' do
    security_orchestration_policy_configuration
    sequence(:name) { |n| "security-policy-#{n}" }
    checksum { Digest::SHA256.hexdigest(rand.to_s) }
    policy_index { 0 }
    type { Security::Policy.types[:approval_policy] }
    enabled { true }
    metadata { {} }
    scope { {} }
    content { {} }
    security_policy_management_project_id do
      security_orchestration_policy_configuration.security_policy_management_project_id
    end
    require_approval

    transient do
      linked_projects { [] }
    end

    after(:create) do |policy, evaluator|
      evaluator.linked_projects.each do |project|
        create(:security_policy_project_link, project: project, security_policy: policy)
      end
    end

    transient do
      bypass_access_token_ids { [] }
      bypass_service_account_ids { [] }
    end

    after(:build) do |policy, evaluator|
      next if evaluator.bypass_access_token_ids.blank?

      policy.content ||= {}
      policy.content[:bypass_settings] ||= {}
      policy.content[:bypass_settings][:access_tokens] = evaluator.bypass_access_token_ids.map do |token_id|
        { id: token_id }
      end

      next if evaluator.bypass_service_account_ids.blank?

      policy.content[:bypass_settings] ||= {}
      policy.content[:bypass_settings][:service_accounts] = evaluator
        .bypass_service_account_ids.map { |service_account_id| { id: service_account_id } }
    end

    trait :deleted do
      policy_index { -1 }
    end

    trait :with_policy_scope do
      scope do
        {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ],
          projects: {
            including: [
              { id: 1 }
            ],
            excluding: [
              { id: 2 }
            ]
          }
        }
      end
    end

    trait :require_approval do
      content { { actions: [{ type: 'require_approval', approvals_required: 1, user_approvers: %w[owner] }] } }
    end

    trait :warn_mode do
      content do
        { actions: [
          { type: 'require_approval', approvals_required: 0, user_approvers: %w[owner] },
          { type: 'send_bot_message', enabled: true }
        ] }
      end
    end

    trait :with_approval_settings do
      content { { approval_settings: { prevent_approval_by_author: true } } }
    end

    trait :approval_policy do
      transient do
        approval_policy_rules_data do
          [
            {
              type: :scan_finding,
              content: {
                type: 'scan_finding',
                branches: [],
                scanners: %w[container_scanning],
                vulnerabilities_allowed: 0,
                severity_levels: %w[critical],
                vulnerability_states: %w[detected]
              }
            }
          ]
        end
      end

      after(:create) do |policy, evaluator|
        evaluator.approval_policy_rules_data.each_with_index do |rule_data, idx|
          create(:approval_policy_rule, rule_data[:type], security_policy: policy, rule_index: idx,
            content: rule_data[:content])
        end
      end
    end

    trait :scan_execution_policy do
      type { Security::Policy.types[:scan_execution_policy] }
      content { { actions: [{ scan: 'secret_detection' }], skip_ci: { allowed: true } } }
    end

    trait :pipeline_execution_policy do
      type { Security::Policy.types[:pipeline_execution_policy] }
      content do
        {
          content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
          pipeline_config_strategy: 'inject_ci',
          skip_ci: { allowed: false },
          variables_override: { allowed: false }
        }
      end
    end

    trait :vulnerability_management_policy do
      type { Security::Policy.types[:vulnerability_management_policy] }
      content do
        {
          actions: [{ type: 'auto_resolve' }]
        }
      end
    end

    trait :pipeline_execution_schedule_policy do
      type { Security::Policy.types[:pipeline_execution_schedule_policy] }
      content do
        {
          content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
          schedules: [
            { type: "daily", start_time: "00:00", time_window: { value: 4000, distribution: 'random' } }
          ]
        }
      end
    end
  end

  factory :scan_execution_policy,
    class: Struct.new(:name, :description, :enabled, :actions, :rules, :policy_scope, :metadata, :skip_ci) do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      actions = attributes[:actions]
      rules = attributes[:rules]
      policy_scope = attributes[:policy_scope]
      metadata = attributes[:metadata]
      skip_ci = attributes[:skip_ci]

      new(name, description, enabled, actions, rules, policy_scope, metadata, skip_ci).to_h.then do |hash|
        hash.except!(:skip_ci) unless hash[:skip_ci]
        hash
      end
    end

    transient do
      agent { 'agent-name' }
      namespaces { %w[namespace-a namespace-b] }
    end

    sequence(:name) { |n| "test-policy-#{n}" }
    description { 'This policy enforces to run DAST for every pipeline within the project' }
    enabled { true }
    rules { [{ type: 'pipeline', branches: %w[master] }] }
    actions { [{ scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' }] }
    policy_scope { {} }
    metadata { {} }
    skip_ci { nil }

    trait :with_schedule do
      rules { [{ type: 'schedule', branches: %w[master], cadence: '*/15 * * * *' }] }
    end

    trait :with_schedule_and_agent do
      rules { [{ type: 'schedule', agents: { agent.name => { namespaces: namespaces } }, cadence: '30 2 * * *' }] }
      actions { [{ scan: 'container_scanning' }] }
    end

    trait :skip_ci_disallowed do
      skip_ci { { allowed: false } }
    end

    trait :skip_ci_allowed do
      skip_ci { { allowed: true } }
    end
  end

  factory :vulnerability_management_policy,
    class: Struct.new(:name, :description, :enabled, :rules, :actions, :policy_scope) do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      rules = attributes[:rules]
      actions = attributes[:actions]
      policy_scope = attributes[:policy_scope]

      new(name, description, enabled, rules, actions, policy_scope).to_h
    end

    sequence(:name) { |n| "test-vulnerability-management-policy-#{n}" }
    description { 'This policy enforces resolving of no longer detected low SAST vulnerabilities' }
    enabled { true }
    rules do
      [
        {
          type: 'no_longer_detected',
          scanners: %w[sast],
          severity_levels: %w[low]
        }
      ]
    end
    actions { [{ type: 'auto_resolve' }] }
    policy_scope { {} }
  end

  factory :ci_component_publishing_policy,
    class: Struct.new(:name, :description, :enabled, :allowed_sources, :policy_scope, :metadata) do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      allowed_sources = attributes[:allowed_sources]
      policy_scope = attributes[:policy_scope]
      metadata = attributes[:metadata]

      new(name, description, enabled, allowed_sources, policy_scope, metadata).to_h
    end

    sequence(:name) { |n| "ci-component-sources-policy-#{n}" }
    description { 'This policy enforces an allowlist of groups and projects that can publish CI/CD components' }
    enabled { true }
    metadata { {} }
    allowed_sources { {} }
    policy_scope { {} }

    trait :with_policy_scope do
      policy_scope do
        {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ],
          projects: {
            including: [],
            excluding: []
          }
        }
      end
    end
  end

  factory :pipeline_execution_policy,
    class: Struct.new(:name, :description, :enabled, :pipeline_config_strategy, :content, :policy_scope, :metadata,
      :suffix, :skip_ci, :variables_override) do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      pipeline_config_strategy = attributes[:pipeline_config_strategy]
      content = attributes[:content]
      policy_scope = attributes[:policy_scope]
      metadata = attributes[:metadata]
      suffix = attributes[:suffix]
      skip_ci = attributes[:skip_ci]
      variables_override = attributes[:variables_override]

      new(name, description, enabled, pipeline_config_strategy, content, policy_scope, metadata, suffix, skip_ci,
        variables_override).to_h.tap do |result|
        result.delete(:variables_override) if result[:variables_override].blank?
      end
    end

    sequence(:name) { |n| "test-pipeline-execution-policy-#{n}" }
    description { 'This policy enforces execution of custom CI in the pipeline' }
    enabled { true }
    sequence(:content) { |n| { include: [{ project: 'compliance-project', file: "compliance-pipeline-#{n}.yml" }] } }
    pipeline_config_strategy { 'inject_ci' }
    policy_scope { {} }
    metadata { {} }
    suffix { nil }
    skip_ci { { allowed: false } }
    variables_override { nil }

    trait :override_project_ci do
      pipeline_config_strategy { 'override_project_ci' }
    end

    trait :inject_policy do
      pipeline_config_strategy { 'inject_policy' }
    end

    trait :suffix_on_conflict do
      suffix { 'on_conflict' }
    end

    trait :suffix_never do
      suffix { 'never' }
    end

    trait :skip_ci_allowed do
      skip_ci { { allowed: true } }
    end

    trait :skip_ci_disallowed do
      skip_ci { { allowed: false } }
    end

    trait :variables_override_disallowed do
      variables_override { { allowed: false } }
    end

    trait :with_policy_scope do
      policy_scope do
        {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ],
          projects: {
            including: [],
            excluding: []
          }
        }
      end
    end
  end

  factory :pipeline_execution_schedule_policy,
    class: Struct.new(:name, :description, :enabled, :content, :schedules, :policy_scope, :metadata) do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      content = attributes[:content]
      schedules = attributes[:schedules]
      policy_scope = attributes[:policy_scope]
      metadata = attributes[:metadata]

      new(name, description, enabled, content, schedules, policy_scope, metadata).to_h
    end

    sequence(:name) { |n| "test-pipeline-execution-schedule-policy-#{n}" }
    description { 'TODO' }
    enabled { true }
    sequence(:content) { |n| { include: [{ project: 'compliance-project', file: "compliance-pipeline-#{n}.yml" }] } }
    policy_scope { {} }
    metadata { {} }
    schedules { [{ type: "daily", start_time: "00:00", time_window: { value: 4000, distribution: 'random' } }] }

    trait :with_policy_scope do
      policy_scope do
        {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ],
          projects: {
            including: [],
            excluding: []
          }
        }
      end
    end
  end

  factory :approval_policy,
    class: Struct.new(:name, :description, :enabled, :actions, :rules, :approval_settings, :policy_scope,
      :fallback_behavior, :metadata, :policy_tuning) do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      actions = attributes[:actions]
      rules = attributes[:rules]
      approval_settings = attributes[:approval_settings]
      policy_scope = attributes[:policy_scope]
      fallback_behavior = attributes[:fallback_behavior]
      policy_tuning = attributes[:policy_tuning]
      metadata = attributes[:metadata]

      new(name, description, enabled, actions, rules, approval_settings, policy_scope, fallback_behavior, metadata,
        policy_tuning).to_h
    end

    transient do
      branches { ['master'] }
      vulnerability_attributes { {} }
      commits { 'unsigned' }
    end

    sequence(:name) { |n| "test-policy-#{n}" }
    description { 'This policy considers only container scanning and critical severities' }
    enabled { true }
    metadata { {} }
    rules do
      [
        {
          type: 'scan_finding',
          branches: branches,
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected],
          vulnerability_attributes: vulnerability_attributes
        }
      ]
    end

    actions { [{ type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] }] }
    approval_settings { {} }
    policy_scope { {} }
    fallback_behavior { {} }
    policy_tuning { {} }

    trait :license_finding do
      rules do
        [
          {
            type: 'license_finding',
            branches: branches,
            match_on_inclusion_license: true,
            license_types: %w[BSD MIT],
            license_states: %w[newly_detected detected]
          }
        ]
      end
    end

    trait :license_finding_with_allowed_licenses do
      rules do
        [
          {
            type: 'license_finding',
            branches: branches,
            license_states: %w[newly_detected detected],
            licenses: {
              allowed: [
                {
                  name: "MIT License",
                  packages: { excluding: { purls: ["pkg:gem/bundler@1.0.0"] } }
                }
              ]
            }
          }
        ]
      end
    end

    trait :any_merge_request do
      rules do
        [
          {
            type: 'any_merge_request',
            branches: branches,
            commits: commits
          }
        ]
      end
    end

    trait :with_approval_settings do
      approval_settings do
        {
          prevent_approval_by_author: true,
          prevent_approval_by_commit_author: true,
          remove_approvals_with_new_commit: true,
          require_password_to_approve: true,
          block_branch_modification: true,
          prevent_pushing_and_force_pushing: true
        }
      end
    end

    trait :with_policy_scope do
      policy_scope do
        {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ],
          projects: {
            including: [
              { id: 1 }
            ],
            excluding: [
              { id: 2 }
            ]
          }
        }
      end
    end

    trait :with_disabled_bot_message do
      actions do
        [
          { type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] },
          { type: 'send_bot_message', enabled: false }
        ]
      end
    end

    trait :fail_open do
      fallback_behavior { { fail: "open" } }
    end
  end

  factory :orchestration_policy_yaml,
    class: Struct.new(
      :scan_execution_policy,
      :approval_policy,
      :pipeline_execution_policy,
      :ci_component_publishing_policy,
      :vulnerability_management_policy,
      :pipeline_execution_schedule_policy,
      :experiments
    ) do
    skip_create

    initialize_with do
      YAML.dump(new(**attributes).to_h.compact.deep_stringify_keys)
    end
  end
end
