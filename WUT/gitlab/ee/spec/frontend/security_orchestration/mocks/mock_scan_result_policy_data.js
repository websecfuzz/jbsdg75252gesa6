/**
 * Naming convention for mocks:
 * mock policy yaml => name ends in `ScanResultManifest`
 * mock parsed yaml => name ends in `ScanResultObject`
 * mock policy for list/drawer => name ends in `ScanResultPolicy`
 *
 * If you have the same policy in multiple forms (e.g. mock yaml and mock parsed yaml that should
 * match), please name them similarly (e.g. fooBarScanResultManifest and fooBarScanResultObject)
 * and keep them near each other.
 */
import { POLICY_SCOPE_MOCK } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { actionId, ruleId } from './mock_data';

export const mockNoFallbackScanResultManifest = `type: approval_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
  - type: send_bot_message
    enabled: true
`;

export const mockNoFallbackScanResultManifestNewFormat = `name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
  - type: send_bot_message
    enabled: true
`;

export const mockDefaultBranchesScanResultManifest =
  mockNoFallbackScanResultManifest.concat(`fallback_behavior:
  fail: open
`);

export const mockDefaultBranchesScanResultManifestWithWrapper = `approval_policy:
  - name: critical vulnerability CS approvals
    description: This policy enforces critical vulnerability CS approvals
    enabled: true
    rules:
      - type: scan_finding
        branches: []
        scanners:
          - container_scanning
        vulnerabilities_allowed: 1
        severity_levels:
          - critical
        vulnerability_states:
          - newly_detected
    actions:
      - type: require_approval
        approvals_required: 1
        user_approvers:
          - the.one
      - type: send_bot_message
        enabled: true
    fallback_behavior:
      fail: open
`;

export const mockDefaultBranchesScanResultManifestNewFormat =
  mockNoFallbackScanResultManifestNewFormat.concat(`fallback_behavior:
  fail: open
`).concat(`type: approval_policy
`);

export const mockDefaultBranchesScanResultObject = {
  type: 'approval_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
      id: actionId,
    },
    { type: 'send_bot_message', enabled: true, id: `action_0` },
  ],
  fallback_behavior: {
    fail: 'open',
  },
};

export const mockDefaultBranchesScanResultObjectWithoutBotAction = {
  ...mockDefaultBranchesScanResultObject,
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
      id: actionId,
    },
  ],
};

export const mockDeprecatedScanResultManifest = `approval_policy:
  - name: critical vulnerability CS approvals
    description: This policy enforces critical vulnerability CS approvals
    enabled: true
    rules:
      - type: scan_finding
        branches: []
        scanners:
          - container_scanning
        vulnerabilities_allowed: 1
        severity_levels:
          - critical
        vulnerability_states:
          - newly_detected
    actions:
      - type: require_approval
        approvals_required: 1
        user_approvers:
          - the.one
    fallback_behavior:
      fail: open
`;

export const zeroActionsScanResultManifest = `type: approval_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
`;

export const zeroActionsScanResultObject = {
  type: 'approval_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
};

export const multipleApproverActionsScanResultManifest = zeroActionsScanResultManifest.concat(`
actions:
  - type: require_approval
    approvals_required: 1
  - type: send_bot_message
    enabled: true
  - type: require_approval
    approvals_required: 1
`);

export const multipleApproverActionsScanResultObject = {
  type: 'approval_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
  actions: [
    { type: 'require_approval', approvals_required: 1, id: actionId },
    { type: 'send_bot_message', enabled: true, id: actionId },
    { type: 'require_approval', approvals_required: 1, id: actionId },
  ],
};

export const enabledSendBotMessageActionScanResultManifest = zeroActionsScanResultManifest.concat(`
actions:
  - type: send_bot_message
    enabled: true
`);

export const disabledSendBotMessageActionScanResultManifest = zeroActionsScanResultManifest.concat(`
actions:
  - type: send_bot_message
    enabled: false
`);

export const mockDeprecatedScanResultObject = {
  type: 'scan_result_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
      id: actionId,
    },
  ],
};

export const mockProjectScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  csp: false,
  name: `${mockDefaultBranchesScanResultObject.name}-project`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  deprecatedProperties: [],
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: false,
  actionApprovers: [],
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockProjectScanResultPolicyCombinedList = {
  __typename: 'ScanResultPolicy',
  csp: false,
  policyAttributes: {
    __typename: 'ApprovalPolicyAttributesType',
    actionApprovers: [],
    deprecatedProperties: [],
    source: {
      __typename: 'ProjectSecurityPolicySource',
      project: {
        fullPath: 'project/path',
      },
    },
  },
  name: `${mockDefaultBranchesScanResultObject.name}-project`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  deprecatedProperties: [],
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: false,
  actionApprovers: [],
  type: 'approval_policy',
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockGroupScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  csp: false,
  name: `${mockDefaultBranchesScanResultObject.name}-group`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  deprecatedProperties: [],
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: mockDefaultBranchesScanResultObject.enabled,
  actionApprovers: [],
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockGroupScanResultPolicyCombinedList = {
  __typename: 'ScanResultPolicy',
  csp: false,
  name: `${mockDefaultBranchesScanResultObject.name}-group`,
  policyAttributes: {
    __typename: 'ApprovalPolicyAttributesType',
    deprecatedProperties: [],
    actionApprovers: [],
    source: {
      __typename: 'GroupSecurityPolicySource',
      inherited: true,
      namespace: {
        __typename: 'Namespace',
        id: '1',
        fullPath: 'parent-group-path',
        name: 'parent-group-name',
      },
    },
  },
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  deprecatedProperties: [],
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: mockDefaultBranchesScanResultObject.enabled,
  actionApprovers: [],
  ...POLICY_SCOPE_MOCK,
  type: 'approval_policy',
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockApprovalSettingsPermittedInvalidScanResultManifest =
  mockNoFallbackScanResultManifest
    .concat(
      `
approval_settings:
  block_protected_branch_modification:
    enabled: true
`,
    )
    .concat('fallback_behavior:\n  fail: open');

export const mockPolicyScopeScanResultManifest = `type: approval_policy
name: policy scope
description: This policy enforces policy scope
enabled: true
rules: []
actions: []
policy_scope:
  compliance_frameworks:
    - id: 26
`;

export const mockApprovalSettingsScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  approval_settings: {
    block_branch_modification: true,
    prevent_pushing_and_force_pushing: true,
    prevent_approval_by_author: true,
  },
};

export const allowDenyScanResultLicenseObject = {
  name: 'This policy has license packages with exceptions',
  description: 'This policy license packages with exceptions',
  enabled: true,
  rules: [
    {
      type: 'license_finding',
      id: 'rule_0',
      match_on_inclusion_license: true,
      license_types: [],
      license_states: [],
      branch_type: 'protected',
      licenses: {
        allowed: [],
      },
    },
  ],
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      id: 'action_0',
    },
  ],
};

export const mockDisabledApprovalSettingsScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  approval_settings: {
    block_branch_modification: false,
    prevent_pushing_and_force_pushing: false,
    block_group_branch_modification: false,
  },
};

export const mockApprovalSettingsPermittedInvalidScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  approval_settings: {
    block_protected_branch_modification: {
      enabled: true,
    },
  },
  fallback_behavior: { fail: 'open' },
};

export const allowDenyScanResultLicenseNonEmptyManifest = `---
name: This policy has license packages with exceptions
description: This policy license packages with exceptions
enabled: true
rules:
  - type: license_finding
    match_on_inclusion_license: true
    license_types: ['MIT']
    license_states:
      - detected
    branch_type: protected
    licenses:
      allowed:
        - name: MIT
          packages: []
        - name: NPM
          packages:
            excluding:
              purls:
                - pkg:npm40angular/animation
                - pkg:npm40angular/animation@12.3.1
actions:
  - type: require_approval
    approvals_required: 1
`;

export const denyScanResultLicenseNonEmptyManifest =
  allowDenyScanResultLicenseNonEmptyManifest.replace('allowed', 'denied');

export const mockWithBranchesScanResultManifest = `type: approval_policy
name: low vulnerability SAST approvals
description: This policy enforces low vulnerability SAST approvals
enabled: true
rules:
  - type: scan_finding
    branches:
      - main
    scanners:
      - sast
    vulnerabilities_allowed: 1
    severity_levels:
      - low
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
`;

export const mockProjectWithBranchesScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  csp: false,
  name: 'low vulnerability SAST approvals',
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockWithBranchesScanResultManifest,
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: true,
  actionApprovers: [],
  userApprovers: [{ name: 'the.one' }],
  allGroupApprovers: [],
  roleApprovers: [],
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path/second',
    },
  },
};

export const mockProjectWithAllApproverTypesScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  csp: false,
  name: mockDefaultBranchesScanResultObject.name,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: false,
  actionApprovers: [
    {
      users: [{ name: 'the.one' }],
      allGroups: [{ fullPath: 'the.one.group' }],
      roles: ['OWNER'],
    },
  ],
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockProjectFallbackClosedScanResultManifest =
  mockDefaultBranchesScanResultManifest.concat(`fallback_behavior:\n  fail: closed`);

export const mockProjectFallbackClosedScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  fallback_behavior: {
    fail: 'closed',
  },
};

export const mockProjectPolicyTuningScanResultManifest =
  mockDefaultBranchesScanResultManifest.concat(
    `policy_tuning:\n  unblock_rules_using_execution_policies: true`,
  );

export const mockProjectPolicyTuningScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  policy_tuning: {
    unblock_rules_using_execution_policies: true,
  },
};

export const mockInvalidRulesScanResultManifest = `type: approval_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - fake_container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions: []
`;

export const mockInvalidApprovalSettingScanResultManifest = mockDefaultBranchesScanResultManifest
  .concat(`approval_settings:\n  fake_block_branch_modification: true\n`)
  .concat(`fallback_behavior:\n  fail: open`);

export const mockInvalidGroupApprovalSettingStructureScanResultManifest =
  mockDefaultBranchesScanResultManifest
    .concat(`approval_settings:\n  prevent_pushing_and_force_pushing:\n   []\n`)
    .concat(`fallback_behavior:\n  fail: open`);

export const mockProjectApprovalSettingsScanResultManifest = mockDefaultBranchesScanResultManifest
  .concat(
    `
approval_settings:
  block_branch_modification: true
  prevent_pushing_and_force_pushing: true
  prevent_approval_by_author: true
`,
  )
  .concat(`fallback_behavior:\n  fail: open`);

export const mockGroupApprovalSettingsScanResultManifest = mockDefaultBranchesScanResultManifest
  .concat(
    `
approval_settings:
  block_branch_modification: true
  block_group_branch_modification:
    enabled: true
    exceptions:
      - release/*
  prevent_pushing_and_force_pushing: true
`,
  )
  .concat(`fallback_behavior:\n  fail: open`);

export const mockGroupApprovalSettingsScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  approval_settings: {
    block_branch_modification: true,
    block_group_branch_modification: {
      enabled: true,
      exceptions: ['release/*'],
    },
    prevent_pushing_and_force_pushing: true,
  },
};

export const mockWarnActionScanResultManifest = zeroActionsScanResultManifest.concat(`actions:
  - type: require_approval
    approvals_required: 0
    role_approvers:
      - owner
  - type: send_bot_message
    enabled: true
`);

export const mockWarnActionScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  actions: [
    {
      type: 'require_approval',
      approvals_required: 0,
      id: actionId,
    },
    { type: 'send_bot_message', enabled: true, id: `action_0` },
  ],
};

const defaultScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  csp: false,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: true,
  userApprovers: [{ name: 'the.one' }],
  allGroupApprovers: [],
  roleApprovers: [],
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path/second',
    },
  },
};

export const mockProjectApprovalSettingsScanResultPolicy = {
  ...defaultScanResultPolicy,
  name: 'low vulnerability SAST approvals',
  yaml: mockProjectApprovalSettingsScanResultManifest,
  approval_settings: {
    block_branch_modification: true,
    prevent_pushing_and_force_pushing: true,
    prevent_approval_by_author: true,
  },
};

export const mockScanResultPoliciesResponse = [
  mockProjectScanResultPolicy,
  mockGroupScanResultPolicy,
];

export const createApprovers = ({
  group = false,
  user = false,
  role = false,
  customRole = false,
}) => {
  const mockUser = {
    webUrl: `webUrl1`,
    __typename: 'UserCore',
    name: `username1`,
    id: `gid://gitlab/User/1`,
  };

  const mockGroup = {
    webUrl: `webUrl2`,
    __typename: 'Group',
    fullPath: `grouppath2`,
    id: `gid://gitlab/Group/2`,
  };

  const mockCustomRole = {
    __typename: 'MemberRole',
    name: `Custom`,
    id: `gid://gitlab/MemberRole/3`,
  };

  return []
    .concat(group ? mockGroup : [])
    .concat(user ? mockUser : [])
    .concat(role ? 'Owner' : [])
    .concat(customRole ? mockCustomRole : []);
};

export const mockFallbackInvalidScanResultManifest = mockDefaultBranchesScanResultManifest.concat(
  `fallback_behavior:\n  fail: something_else`,
);
