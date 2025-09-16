import {
  addIdsToPolicy,
  checkForPerformanceRisk,
  hasScheduledRule,
  isPolicyInherited,
  policyHasNamespace,
  isDefaultMode,
  policyScopeHasExcludingProjects,
  policyScopeHasIncludingProjects,
  policyScopeProjectsKey,
  policyScopeHasComplianceFrameworks,
  policyScopeProjectLength,
  policyScopeComplianceFrameworks,
  policyScopeProjects,
  policyScopeGroups,
  policyScopeHasGroups,
  policyExcludingProjects,
  isProject,
  isGroup,
  isScanningReport,
  extractPolicyContent,
} from 'ee/security_orchestration/components/utils';
import {
  EXCLUDING,
  INCLUDING,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { DEFAULT_SCAN_EXECUTION_POLICY } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import {
  mockDastScanExecutionObject,
  mockDastScanExecutionManifest,
  mockScheduleScanExecutionObject,
  mockScheduleScanExecutionManifest,
} from '../mocks/mock_scan_execution_policy_data';

describe('addIdsToPolicy', () => {
  it('adds ids to a policy with actions and rules', () => {
    expect(addIdsToPolicy({ actions: [{}], rules: [{}] })).toStrictEqual({
      actions: [{ id: 'action_1' }],
      rules: [{ id: 'rule_2' }],
    });
  });

  it('does not add ids to a policy with no actions and no rules', () => {
    expect(addIdsToPolicy({ name: 'the best' })).toStrictEqual({ name: 'the best' });
  });
});

describe(isPolicyInherited, () => {
  it.each`
    input                   | output
    ${undefined}            | ${false}
    ${{}}                   | ${false}
    ${{ inherited: false }} | ${false}
    ${{ inherited: true }}  | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isPolicyInherited(input)).toBe(output);
  });
});

describe(policyHasNamespace, () => {
  it.each`
    input                              | output
    ${undefined}                       | ${false}
    ${{}}                              | ${false}
    ${{ namespace: undefined }}        | ${false}
    ${{ namespace: {} }}               | ${true}
    ${{ namespace: { name: 'name' } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyHasNamespace(input)).toBe(output);
  });
});

describe(isDefaultMode, () => {
  it.each`
    input                                      | output
    ${undefined}                               | ${true}
    ${{}}                                      | ${true}
    ${null}                                    | ${true}
    ${{ complianceFrameworks: { nodes: [] } }} | ${false}
    ${{ excludingProjects: { nodes: [] } }}    | ${false}
    ${{ includingProjects: { nodes: [] } }}    | ${false}
    ${{
  complianceFrameworks: { nodes: [] },
  excludingProjects: { nodes: [] },
  includingProjects: { nodes: [] },
}} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isDefaultMode(input)).toBe(output);
  });
});

describe(policyScopeHasExcludingProjects, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${false}
    ${{}}                                                       | ${false}
    ${null}                                                     | ${false}
    ${{ complianceFrameworks: [] }}                             | ${false}
    ${{ includingProjects: { nodes: [] } }}                     | ${false}
    ${{ excludingProjects: { nodes: [] } }}                     | ${false}
    ${{ excludingProjects: { nodes: [{}] } }}                   | ${true}
    ${{ excludingProjects: { nodes: [undefined] } }}            | ${false}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeHasExcludingProjects(input)).toBe(output);
  });
});

describe(policyScopeHasIncludingProjects, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${false}
    ${{}}                                                       | ${false}
    ${null}                                                     | ${false}
    ${{ complianceFrameworks: [] }}                             | ${false}
    ${{ includingProjects: { nodes: [] } }}                     | ${false}
    ${{ excludingProjects: { nodes: [] } }}                     | ${false}
    ${{ excludingProjects: { nodes: [{}] } }}                   | ${false}
    ${{ excludingProjects: { nodes: [undefined] } }}            | ${false}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${false}
    ${{ includingProjects: { nodes: [undefined] } }}            | ${false}
    ${{ includingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeHasIncludingProjects(input)).toBe(output);
  });
});

describe(policyScopeProjectsKey, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${EXCLUDING}
    ${{}}                                                       | ${EXCLUDING}
    ${null}                                                     | ${EXCLUDING}
    ${{ complianceFrameworks: { nodes: [] } }}                  | ${EXCLUDING}
    ${{ includingProjects: { nodes: [] } }}                     | ${EXCLUDING}
    ${{ excludingProjects: { nodes: [] } }}                     | ${EXCLUDING}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${EXCLUDING}
    ${{ includingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${INCLUDING}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeProjectsKey(input)).toBe(output);
  });
});

describe(policyScopeHasComplianceFrameworks, () => {
  it.each`
    input                                               | output
    ${undefined}                                        | ${false}
    ${{}}                                               | ${false}
    ${null}                                             | ${false}
    ${{ complianceFrameworks: [] }}                     | ${false}
    ${{ complianceFrameworks: { nodes: [{}] } }}        | ${true}
    ${{ complianceFrameworks: { nodes: undefined } }}   | ${false}
    ${{ complianceFrameworks: { nodes: [{ id: 1 }] } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeHasComplianceFrameworks(input)).toBe(output);
  });
});

describe(policyScopeHasGroups, () => {
  it.each`
    input                                                     | output
    ${undefined}                                              | ${false}
    ${{}}                                                     | ${false}
    ${null}                                                   | ${false}
    ${{ includingGroups: { nodes: [] } }}                     | ${false}
    ${{ includingGroups: { nodes: [{}] } }}                   | ${true}
    ${{ includingGroups: { nodes: [undefined] } }}            | ${false}
    ${{ includingGroups: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeHasGroups(input)).toBe(output);
  });
});

describe(policyScopeProjectLength, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${0}
    ${{}}                                                       | ${0}
    ${null}                                                     | ${0}
    ${{ complianceFrameworks: { nodes: [] } }}                  | ${0}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${2}
    ${{ includingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${2}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeProjectLength(input)).toBe(output);
  });
});

describe(policyScopeComplianceFrameworks, () => {
  it.each`
    input                                                          | output
    ${undefined}                                                   | ${[]}
    ${{}}                                                          | ${[]}
    ${null}                                                        | ${[]}
    ${{ complianceFrameworks: { nodes: [] } }}                     | ${[]}
    ${{ includingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }}    | ${[]}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }}    | ${[]}
    ${{ complianceFrameworks: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${[{ id: 1 }, { id: 2 }]}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeComplianceFrameworks(input)).toEqual(output);
  });
});

describe(policyScopeProjects, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${{ pageInfo: {}, projects: [] }}
    ${{}}                                                       | ${{ pageInfo: {}, projects: [] }}
    ${null}                                                     | ${{ pageInfo: {}, projects: [] }}
    ${{ compliance_frameworks: [] }}                            | ${{ pageInfo: {}, projects: [] }}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${{ pageInfo: {}, projects: [{ id: 1 }, { id: 2 }] }}
    ${{ includingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${{ pageInfo: {}, projects: [{ id: 1 }, { id: 2 }] }}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeProjects(input)).toEqual(output);
  });
});

describe(policyScopeGroups, () => {
  it.each`
    input                                                     | output
    ${undefined}                                              | ${[]}
    ${{}}                                                     | ${[]}
    ${null}                                                   | ${[]}
    ${{ excludingGroups: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${[]}
    ${{ includingGroups: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${[{ id: 1 }, { id: 2 }]}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeGroups(input)).toEqual(output);
  });
});

describe(policyExcludingProjects, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${[]}
    ${{}}                                                       | ${[]}
    ${null}                                                     | ${[]}
    ${{ excludingProjects: { nodes: [undefined] } }}            | ${[]}
    ${{ excludingProjects: { nodes: [{}] } }}                   | ${[{}]}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${[{ id: 1 }, { id: 2 }]}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyExcludingProjects(input)).toEqual(output);
  });
});

describe(isProject, () => {
  it.each`
    input                      | output
    ${NAMESPACE_TYPES.PROJECT} | ${true}
    ${NAMESPACE_TYPES.GROUP}   | ${false}
    ${null}                    | ${false}
    ${undefined}               | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isProject(input)).toEqual(output);
  });
});

describe(isGroup, () => {
  it.each`
    input                      | output
    ${NAMESPACE_TYPES.PROJECT} | ${false}
    ${NAMESPACE_TYPES.GROUP}   | ${true}
    ${null}                    | ${false}
    ${undefined}               | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isGroup(input)).toEqual(output);
  });
});

describe(isScanningReport, () => {
  it.each`
    input                    | output
    ${'container_scanning'}  | ${true}
    ${'dependency_scanning'} | ${true}
    ${'sast'}                | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isScanningReport(input)).toEqual(output);
  });
});

describe('hasScheduledRule', () => {
  it.each`
    title                                                      | policy                                                                                                           | output
    ${'returns false for a non-schedule policy list policy'}   | ${{ __typename: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.typeName, yaml: mockDastScanExecutionManifest }}     | ${false}
    ${'returns true for a schedule policy list policy'}        | ${{ __typename: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.typeName, yaml: mockScheduleScanExecutionManifest }} | ${true}
    ${'returns false for a non-schedule policy editor policy'} | ${mockDastScanExecutionObject}                                                                                   | ${false}
    ${'returns true for a schedule policy editor policy'}      | ${mockScheduleScanExecutionObject}                                                                               | ${true}
  `('$title', ({ policy, output }) => {
    expect(hasScheduledRule(policy)).toBe(output);
  });
});

describe('checkForPerformanceRisk', () => {
  it.each`
    policyDesc                         | namespaceType              | policy                             | projectsCount | output
    ${'does not have a schedule rule'} | ${NAMESPACE_TYPES.PROJECT} | ${mockDastScanExecutionObject}     | ${0}          | ${false}
    ${'does not have a schedule rule'} | ${NAMESPACE_TYPES.GROUP}   | ${mockDastScanExecutionObject}     | ${0}          | ${false}
    ${'has a schedule rule'}           | ${NAMESPACE_TYPES.PROJECT} | ${mockScheduleScanExecutionObject} | ${0}          | ${false}
    ${'has a schedule rule'}           | ${NAMESPACE_TYPES.GROUP}   | ${mockScheduleScanExecutionObject} | ${0}          | ${false}
    ${'does not have a schedule rule'} | ${NAMESPACE_TYPES.PROJECT} | ${mockDastScanExecutionObject}     | ${1001}       | ${false}
    ${'does not have a schedule rule'} | ${NAMESPACE_TYPES.GROUP}   | ${mockDastScanExecutionObject}     | ${1001}       | ${false}
    ${'has a schedule rule'}           | ${NAMESPACE_TYPES.PROJECT} | ${mockScheduleScanExecutionObject} | ${1001}       | ${false}
    ${'has a schedule rule'}           | ${NAMESPACE_TYPES.GROUP}   | ${mockScheduleScanExecutionObject} | ${1001}       | ${true}
  `(
    'returns $output when namespaceType is $namespaceType, the policy $policyDesc, and projectsCount is $projectsCount',
    ({ namespaceType, policy, projectsCount, output }) => {
      expect(checkForPerformanceRisk({ namespaceType, policy, projectsCount })).toBe(output);
    },
  );

  describe('extractPolicyContent', () => {
    const defaultPayload = {};
    const extractedPolicyContent = {
      actions: [{ scan: 'secret_detection' }],
      description: '',
      enabled: true,
      name: '',
      rules: [{ branches: ['*'], type: 'pipeline' }],
      skip_ci: {
        allowed: true,
      },
    };

    it.each`
      type                       | manifest                         | withType | expectedManifest
      ${'scan_execution_policy'} | ${DEFAULT_SCAN_EXECUTION_POLICY} | ${false} | ${extractedPolicyContent}
      ${'scan_execution_policy'} | ${DEFAULT_SCAN_EXECUTION_POLICY} | ${true}  | ${{ ...extractedPolicyContent, type: 'scan_execution_policy' }}
      ${'scan_execution_policy'} | ${''}                            | ${true}  | ${defaultPayload}
    `(
      'returns output without type wrapper for $type and withType $withType',
      ({ type, manifest, withType, expectedManifest }) => {
        expect(extractPolicyContent({ manifest, type, withType })).toEqual(expectedManifest);
      },
    );
  });
});
