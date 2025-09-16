import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';

export const mockScanExecutionManifest = `scan_execution_policy:
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
`;

const mockScanExecutionManifestParsed = `scan_execution_policy:
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
`;

export const mockDastActionScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: dast
        site_profile: ''
        scanner_profile: ''
    skip_ci:
      allowed: true
`;

export const mockGroupDastActionScanExecutionManifest = `scan_execution_policy:
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
      - scan: dast
        site_profile: ''
        scanner_profile: ''
    skip_ci:
      allowed: true
`;

export const mockActionsVariablesScanExecutionManifest = `scan_execution_policy:
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
          '': ''
    skip_ci:
      allowed: true
`;

export const createScanActionScanExecutionManifest = (scanType, parsed = false) => {
  const parser = parsed ? mockScanExecutionManifestParsed : mockScanExecutionManifest;
  return parser.replace('scan: secret_detection', `scan: ${scanType}`);
};

export const mockScheduleScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: schedule
        branches: []
        cadence: 0 0 * * *
    actions:
      - scan: secret_detection
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
    skip_ci:
      allowed: true
`;

export const mockSkipCiScanExecutionManifest = `scan_execution_policy:
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
      allowed: false
`;

export const mockScanExecutionObject = fromYaml({
  manifest: mockScanExecutionManifest,
  type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
});
