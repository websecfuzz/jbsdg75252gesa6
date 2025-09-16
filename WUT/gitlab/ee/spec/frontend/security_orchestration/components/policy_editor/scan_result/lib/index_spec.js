import {
  DEFAULT_SCAN_RESULT_POLICY,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS,
  getPolicyYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('getPolicyYaml', () => {
  it.each`
    namespaceType              | expected
    ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_RESULT_POLICY}
    ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS}
  `('returns the yaml for the $namespaceType namespace', ({ namespaceType, expected }) => {
    expect(getPolicyYaml({ isGroup: isGroup(namespaceType) })).toEqual(expected);
  });
});
