import { SELECTION_CONFIG_CUSTOM, SELECTION_CONFIG_DEFAULT } from '../constants';
import { hasPredefinedRuleStrategy } from './rules';
import { hasOnlyAllowedScans, hasUniqueScans, hasSimpleScans } from './actions';

export { createPolicyObject } from './from_yaml';
export * from './to_yaml';
export * from './rules';
export * from './cron';
export * from './actions';

export const optimizedConfiguration = `    rules:
      - type: pipeline
        branch_type: default
      - type: pipeline
        branch_type: target_default
        pipeline_sources:
          including:
            - merge_request_event
    actions:
      - scan: secret_detection
        template: latest
    skip_ci:
      allowed: true`;

export const DEFAULT_SCAN_EXECUTION_POLICY_OPTIMIZED = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
${optimizedConfiguration}`;

export const DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_OPTIMIZED = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      projects:
        excluding: []
${optimizedConfiguration}`;

export const DEFAULT_SCAN_EXECUTION_POLICY = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
    skip_ci:
      allowed: true
`;

export const DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      projects:
        excluding: []
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
    skip_ci:
      allowed: true
`;

export const DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_WITH_DEFAULT_VARIABLES = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
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
`;

export const getPolicyYaml = ({ isGroup }) => {
  const { flexibleScanExecutionPolicy } = window.gon?.features || {};

  if (flexibleScanExecutionPolicy) {
    return isGroup
      ? DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_OPTIMIZED
      : DEFAULT_SCAN_EXECUTION_POLICY_OPTIMIZED;
  }

  return isGroup ? DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE : DEFAULT_SCAN_EXECUTION_POLICY;
};

export const getConfiguration = (policy) => {
  const { actions = [], rules = [] } = policy;
  if (
    hasPredefinedRuleStrategy(rules) &&
    hasOnlyAllowedScans(actions) &&
    hasUniqueScans(actions) &&
    hasSimpleScans(actions)
  ) {
    return SELECTION_CONFIG_DEFAULT;
  }

  return SELECTION_CONFIG_CUSTOM;
};
