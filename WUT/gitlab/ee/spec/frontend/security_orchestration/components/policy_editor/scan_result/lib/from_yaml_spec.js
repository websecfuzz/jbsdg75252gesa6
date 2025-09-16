import {
  DEFAULT_SCAN_RESULT_POLICY,
  createPolicyObject,
  validatePolicy,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import {
  mockDefaultBranchesScanResultManifest,
  mockDefaultBranchesScanResultObject,
  mockApprovalSettingsPermittedInvalidScanResultManifest,
  mockFallbackInvalidScanResultManifest,
  mockInvalidRulesScanResultManifest,
  mockInvalidApprovalSettingScanResultManifest,
  mockInvalidGroupApprovalSettingStructureScanResultManifest,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import {
  invalidYaml,
  unsupportedManifest,
  unsupportedManifestObject,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';

jest.mock('lodash/uniqueId', () => jest.fn((prefix) => `${prefix}0`));

describe('createPolicyObject', () => {
  it.each`
    title                                                                           | input                                    | output
    ${'returns the policy object and no errors for a supported manifest'}           | ${mockDefaultBranchesScanResultManifest} | ${{ policy: mockDefaultBranchesScanResultObject, parsingError: {} }}
    ${'returns the error policy object and the error for an unsupported manifest'}  | ${unsupportedManifest}                   | ${{ policy: { ...unsupportedManifestObject, type: 'approval_policy' }, parsingError: {} }}
    ${'returns the error policy object and the error for an invalid strategy name'} | ${invalidYaml}                           | ${{ policy: {}, parsingError: { actions: true, fallback: true, rules: true, settings: true } }}
  `('$title', ({ input, output }) => {
    expect(createPolicyObject(input)).toStrictEqual(output);
  });
});

describe('validatePolicy', () => {
  it.each`
    title                                                                                    | input                                                         | output
    ${'returns empty object when there are no errors'}                                       | ${DEFAULT_SCAN_RESULT_POLICY}                                 | ${{}}
    ${'returns empty object with `approval_settings` containing permitted invalid settings'} | ${mockApprovalSettingsPermittedInvalidScanResultManifest}     | ${{}}
    ${'returns error objects for invalid content'}                                           | ${invalidYaml}                                                | ${{ actions: true, fallback: true, rules: true, settings: true }}
    ${'returns error objects for an invalid fallback value'}                                 | ${mockFallbackInvalidScanResultManifest}                      | ${{ fallback: true }}
    ${'returns error objects for an empty policy'}                                           | ${''}                                                         | ${{ actions: true, fallback: true, rules: true, settings: true }}
    ${'returns error objects for invalid rules'}                                             | ${mockInvalidRulesScanResultManifest}                         | ${{ rules: true }}
    ${'returns error objects for invalid settings'}                                          | ${mockInvalidApprovalSettingScanResultManifest}               | ${{ settings: true }}
    ${'returns error objects for invalid setting structure'}                                 | ${mockInvalidGroupApprovalSettingStructureScanResultManifest} | ${{ settings: true }}
  `('$title', ({ input, output }) => {
    expect(
      validatePolicy(
        fromYaml({
          manifest: input,
          type: POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter,
          addIds: true,
        }),
      ),
    ).toStrictEqual(output);
  });
});
