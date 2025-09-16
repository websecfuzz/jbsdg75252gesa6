import { fromYaml } from 'ee/security_orchestration/components/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';

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
`;

export const mockPipelineExecutionOverrideActionManifest = `pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: override_project_ci
    content:
      include:
        - project: ''
    skip_ci:
      allowed: false
    variables_override:
      allowed: false
      exceptions: []
`;

export const mockPipelineExecutionSkipCiManifest = `pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: inject_policy
    content:
      include:
        - project: ''
    skip_ci:
      allowed: true
    variables_override:
      allowed: false
      exceptions: []
`;

export const mockPipelineExecutionSkipCiWithUsersManifest = `pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: inject_policy
    content:
      include:
        - project: ''
    skip_ci:
      allowed: false
      allowlist:
        users:
          - id: 1
`;

export const mockPipelineExecutionObject = fromYaml({
  manifest: mockPipelineExecutionActionManifest,
  type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
});
