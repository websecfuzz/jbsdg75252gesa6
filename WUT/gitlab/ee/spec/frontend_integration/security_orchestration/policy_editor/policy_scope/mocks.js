export const mockScanExecutionActionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      compliance_frameworks:
        - id: 1
        - id: 2
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
    skip_ci:
      allowed: true
`;

export const mockScanExecutionActionProjectManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
    skip_ci:
      allowed: true
    policy_scope:
      compliance_frameworks:
        - id: 1
        - id: 2
`;

export const mockPipelineExecutionActionManifest = `pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: inject_policy
    content:
      include:
        - project: ''
    skip_ci:
      allowed: false
    variables_override:
      allowed: false
      exceptions: []
    policy_scope:
      compliance_frameworks:
        - id: 1
        - id: 2
`;

export const mockApprovalActionGroupManifest = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      compliance_frameworks:
        - id: 1
        - id: 2
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      block_group_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`;

export const mockApprovalActionProjectManifest = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
    policy_scope:
      compliance_frameworks:
        - id: 1
        - id: 2
`;

export const EXCLUDING_PROJECTS_MOCKS = {
  SCAN_EXECUTION: `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      projects:
        excluding:
          - id: 1
          - id: 2
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
    skip_ci:
      allowed: true
`,
  PIPELINE_EXECUTION: `name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_policy
content:
  include:
    - project: ''
policy_scope:
  projects:
    excluding:
      - id: 1
      - id: 2
type: pipeline_execution_policy
`,
  APPROVAL_POLICY: `approval_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      projects:
        excluding:
          - id: 1
          - id: 2
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      block_group_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`,
};

export const EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS = {
  SCAN_EXECUTION: `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
    skip_ci:
      allowed: true
    policy_scope:
      projects:
        excluding:
          - id: 1
          - id: 2
`,
  PIPELINE_EXECUTION: `pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: inject_policy
    content:
      include:
        - project: ''
    skip_ci:
      allowed: false
    variables_override:
      allowed: false
      exceptions: []
    policy_scope:
      projects:
        excluding:
          - id: 1
          - id: 2
`,
  APPROVAL_POLICY: `approval_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
    policy_scope:
      projects:
        excluding:
          - id: 1
          - id: 2
`,
};

const replaceProjectKey = (value) => value.replace('excluding', 'including');

export const INCLUDING_PROJECTS_MOCKS = {
  SCAN_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_MOCKS.SCAN_EXECUTION),
  PIPELINE_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_MOCKS.PIPELINE_EXECUTION),
  APPROVAL_POLICY: replaceProjectKey(EXCLUDING_PROJECTS_MOCKS.APPROVAL_POLICY),
};

export const INCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS = {
  SCAN_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.SCAN_EXECUTION),
  PIPELINE_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.PIPELINE_EXECUTION),
  APPROVAL_POLICY: replaceProjectKey(EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.APPROVAL_POLICY),
};

export const INCLUDING_GROUPS_WITH_EXCEPTIONS_MOCKS = {
  SCAN_EXECUTION: `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      groups:
        including:
          - id: 1
          - id: 2
      projects:
        excluding: []
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
    skip_ci:
      allowed: true
`,
  PIPELINE_EXECUTION: `pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: inject_policy
    content:
      include:
        - project: ''
    skip_ci:
      allowed: false
    variables_override:
      allowed: false
      exceptions: []
    policy_scope:
      groups:
        including:
          - id: 1
          - id: 2
      projects:
        excluding: []
`,
  APPROVAL_POLICY: `approval_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      groups:
        including:
          - id: 1
          - id: 2
      projects:
        excluding: []
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      block_group_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`,
};

export const INCLUDING_GROUPS_MOCKS = {
  SCAN_EXECUTION: `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      groups:
        including:
          - id: 1
          - id: 2
      projects:
        excluding: []
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
    skip_ci:
      allowed: true
`,
  PIPELINE_EXECUTION: `pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: inject_policy
    content:
      include:
        - project: ''
    skip_ci:
      allowed: false
    variables_override:
      allowed: false
      exceptions: []
    policy_scope:
      groups:
        including:
          - id: 1
          - id: 2
      projects:
        excluding: []
`,
  APPROVAL_POLICY: `approval_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      groups:
        including:
          - id: 1
          - id: 2
      projects:
        excluding: []
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      block_branch_modification: true
      block_group_branch_modification: true
      prevent_pushing_and_force_pushing: true
      prevent_approval_by_author: true
      prevent_approval_by_commit_author: true
      remove_approvals_with_new_commit: true
      require_password_to_approve: false
    fallback_behavior:
      fail: closed
`,
};

export const EXCLUDING_PROJECTS_ON_PROJECT_LEVEL = `pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: inject_policy
    content:
      include:
        - project: ''
    skip_ci:
      allowed: false
    variables_override:
      allowed: false
      exceptions: []
    policy_scope:
      projects:
        excluding:
          - id: 1
          - id: 2
`;

export const INCLUDING_PROJECTS_ON_PROJECT_LEVEL = replaceProjectKey(
  EXCLUDING_PROJECTS_ON_PROJECT_LEVEL,
);
