import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

export const DEFAULT_PROVIDE = {
  designatedAsCsp: false,
  disableScanPolicyUpdate: false,
  disableSecurityPolicyProject: false,
  policyEditorEmptyStateSvgPath: 'path/to/svg',
  namespaceId: 1,
  namespacePath: 'path/to/project',
  namespaceType: NAMESPACE_TYPES.PROJECT,
  scanPolicyDocumentationPath: 'path/to/policy-docs',
  assignedPolicyProject: {},
  createAgentHelpPath: 'path/to/agent-docs',
  enabledExperiments: [],
  globalGroupApproversEnabled: false,
  maxActiveScanExecutionPoliciesReached: false,
  maxActiveScanResultPoliciesReached: false,
  maxActivePipelineExecutionPoliciesReached: false,
  maxActiveVulnerabilityManagementPoliciesReached: false,
  maxPipelineExecutionPoliciesAllowed: 1,
  maxScanExecutionPoliciesAllowed: 5,
  maxScanResultPoliciesAllowed: 5,
  maxVulnerabilityManagementPoliciesAllowed: 5,
  maxScanExecutionPolicyActions: 10,
  policiesPath: 'path/to/policies',
  policyType: 'scan_execution',
  roleApproverTypes: [],
  rootNamespacePath: 'path/to/root',
  parsedSoftwareLicenses: [],
  timezones: [],
  existingPolicy: undefined,
};

export const SCAN_EXECUTION_POLICY = 'scan_execution_policy';
export const PIPELINE_EXECUTION_POLICY = 'pipeline_execution_policy';
export const APPROVAL_POLICY = 'approval_policy';
