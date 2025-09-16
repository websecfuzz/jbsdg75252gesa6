/* eslint-disable no-underscore-dangle */
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { getPolicyType, removeUnnecessaryDashes } from 'ee/security_orchestration/utils';
import {
  mockProjectScanExecutionPolicy,
  mockProjectScanExecutionPolicyCombinedList,
} from './mocks/mock_scan_execution_policy_data';

describe('getPolicyType', () => {
  it.each`
    typeName                                           | field             | output                                                      | useLegacy
    ${''}                                              | ${undefined}      | ${undefined}                                                | ${true}
    ${'UnknownPolicyType'}                             | ${undefined}      | ${undefined}                                                | ${true}
    ${mockProjectScanExecutionPolicy.__typename}       | ${undefined}      | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value}        | ${true}
    ${mockProjectScanExecutionPolicy.__typename}       | ${'urlParameter'} | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter} | ${true}
    ${mockProjectScanExecutionPolicyCombinedList.type} | ${'urlParameter'} | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter} | ${false}
  `(
    'returns $output when used on typeName: $typeName and field: $field',
    ({ typeName, field, output, useLegacy }) => {
      expect(getPolicyType(typeName, field, useLegacy)).toBe(output);
    },
  );
});

describe('removeUnnecessaryDashes', () => {
  it.each`
    input          | output
    ${'---\none'}  | ${'one'}
    ${'two'}       | ${'two'}
    ${'--\nthree'} | ${'--\nthree'}
    ${'four---\n'} | ${'four'}
  `('returns $output when used on $input', ({ input, output }) => {
    expect(removeUnnecessaryDashes(input)).toBe(output);
  });
});
