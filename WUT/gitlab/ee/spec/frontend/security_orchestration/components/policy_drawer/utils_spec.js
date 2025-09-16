import {
  humanizedBranchExceptions,
  mapShortIdsToFullGraphQlFormat,
} from 'ee/security_orchestration/components/policy_drawer/utils';
import { TYPE_COMPLIANCE_FRAMEWORK } from '~/graphql_shared/constants';

describe('humanizedBranchExceptions', () => {
  it.each`
    exceptions                                                                                       | expectedResult
    ${undefined}                                                                                     | ${[]}
    ${[undefined, null]}                                                                             | ${[]}
    ${['test', 'test1']}                                                                             | ${['test', 'test1']}
    ${['test']}                                                                                      | ${['test']}
    ${['test', undefined]}                                                                           | ${['test']}
    ${[{ name: 'test', full_path: 'gitlab/group' }]}                                                 | ${['test (in %{codeStart}gitlab/group%{codeEnd})']}
    ${[{ name: 'test', full_path: 'gitlab/group' }, { name: 'test1', full_path: 'gitlab/project' }]} | ${['test (in %{codeStart}gitlab/group%{codeEnd})', 'test1 (in %{codeStart}gitlab/project%{codeEnd})']}
  `('should humanize branch exceptions', ({ exceptions, expectedResult }) => {
    expect(humanizedBranchExceptions(exceptions)).toEqual(expectedResult);
  });
});

describe('mapShortIdsToFullGraphQlFormat', () => {
  it.each`
    ids          | type                         | expectedResult
    ${[1, 2]}    | ${undefined}                 | ${['gid://gitlab/Project/1', 'gid://gitlab/Project/2']}
    ${[1, 2]}    | ${TYPE_COMPLIANCE_FRAMEWORK} | ${['gid://gitlab/ComplianceManagement::Framework/1', 'gid://gitlab/ComplianceManagement::Framework/2']}
    ${undefined} | ${undefined}                 | ${[]}
    ${null}      | ${null}                      | ${[]}
  `('converts short format to full GraphQl format', ({ ids, type, expectedResult }) => {
    expect(mapShortIdsToFullGraphQlFormat(type, ids)).toEqual(expectedResult);
  });
});
