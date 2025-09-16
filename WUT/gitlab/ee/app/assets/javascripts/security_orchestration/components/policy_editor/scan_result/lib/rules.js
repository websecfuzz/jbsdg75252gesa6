import { isEmpty, uniqueId } from 'lodash';
import { s__, sprintf } from '~/locale';
import Api from 'ee/api';
import { SEVERITY_LEVELS_KEYS, REPORT_TYPES_DEFAULT } from 'ee/security_dashboard/constants';
import { isPositiveInteger } from '~/lib/utils/number_utils';
import {
  ALL_PROTECTED_BRANCHES,
  ANY_COMMIT,
  BRANCH_TYPE_KEY,
  INVALID_PROTECTED_BRANCHES,
  VALID_SCAN_RESULT_BRANCH_TYPE_OPTIONS,
  VULNERABILITY_AGE_OPERATORS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  APPROVAL_VULNERABILITY_STATES,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  AGE_INTERVALS,
  VULNERABILITY_AGE_ALLOWED_KEYS,
  VULNERABILITY_ATTRIBUTES,
  ALLOWED,
} from '../rule/scan_filters/constants';

const REPORT_TYPES_KEYS = Object.keys(REPORT_TYPES_DEFAULT);

export const VULNERABILITY_STATE_KEYS = [
  NEWLY_DETECTED,
  ...Object.keys(APPROVAL_VULNERABILITY_STATES[NEWLY_DETECTED]),
  ...Object.keys(APPROVAL_VULNERABILITY_STATES[PREVIOUSLY_EXISTING]),
];
export const ANY_MERGE_REQUEST = 'any_merge_request';
export const SCAN_FINDING = 'scan_finding';
export const LICENSE_FINDING = 'license_finding';
export const MATCHING = s__('ScanResultPolicy|Matching');
export const EXCEPT = s__('ScanResultPolicy|Except');

export const LICENSE_STATES = {
  newly_detected: s__('ScanResultPolicy|Newly Detected'),
  detected: s__('ScanResultPolicy|Pre-existing'),
};

/*
  Construct a new rule object.
*/
export const securityScanBuildRule = () => ({
  id: uniqueId('rule_'),
  type: SCAN_FINDING,
  scanners: [],
  vulnerabilities_allowed: 0,
  severity_levels: [],
  vulnerability_states: [],
  branch_type: ALL_PROTECTED_BRANCHES.value,
});

export const licenseScanBuildRule = () => {
  return {
    id: uniqueId('rule_'),
    type: LICENSE_FINDING,
    match_on_inclusion_license: true,
    licenses: { [ALLOWED]: [] },
    license_states: [],
    branch_type: ALL_PROTECTED_BRANCHES.value,
  };
};

export const anyMergeRequestBuildRule = () => ({
  id: uniqueId('rule_'),
  type: ANY_MERGE_REQUEST,
  branch_type: ALL_PROTECTED_BRANCHES.value,
  commits: ANY_COMMIT,
});

/*
  Construct a new rule object for when the licenseScanningPolicies flag is on
*/
export const emptyBuildRule = () => ({
  type: '',
});

/**
 * Check if all rule values of certain key are included in the allowedValues list
 * @param {Array} rules - List of rules
 * @param {String} key - Rule key to check
 * @param {Array} allowedValues - List of possible values
 * @param {Boolean} areDuplicatesAllowed - check for duplicates in array
 * @returns
 */
// eslint-disable-next-line max-params
const invalidRuleValues = (rules, key, allowedValues, areDuplicatesAllowed = false) => {
  if (!rules) {
    return false;
  }

  const hasDuplicates = (items = []) => new Set(items).size !== items.length;

  if (!areDuplicatesAllowed && rules.some((rule) => hasDuplicates(rule[key] || []))) {
    return true;
  }

  return rules.some((rule) => (rule[key] || []).some((value) => !allowedValues.includes(value)));
};

export const invalidScanners = (rules) => invalidRuleValues(rules, 'scanners', REPORT_TYPES_KEYS);

export const invalidSeverities = (rules) =>
  invalidRuleValues(rules, 'severity_levels', SEVERITY_LEVELS_KEYS);

export const invalidVulnerabilityStates = (rules) =>
  invalidRuleValues(rules, 'vulnerability_states', VULNERABILITY_STATE_KEYS);

export const invalidVulnerabilityAttributes = (rules) => {
  if (!rules) {
    return false;
  }

  const validAttributes = VULNERABILITY_ATTRIBUTES.map(({ value }) => value);

  return rules
    .filter((rule) => !isEmpty(rule.vulnerability_attributes))
    .flatMap((rule) => rule.vulnerability_attributes)
    .some((attribute) => {
      if (typeof attribute !== 'object') {
        return true;
      }
      return Object.entries(attribute).some(
        ([key, value]) => !validAttributes.includes(key) || typeof value !== 'boolean',
      );
    });
};

export const invalidVulnerabilitiesAllowed = (rules) => {
  if (!rules) {
    return false;
  }

  return rules
    .filter((rule) => rule.vulnerabilities_allowed)
    .map((rule) => rule.vulnerabilities_allowed)
    .some((value) => !isPositiveInteger(value));
};

export const invalidVulnerabilityAge = (rules) => {
  if (!rules) {
    return false;
  }

  const validOperators = VULNERABILITY_AGE_OPERATORS.map(({ value }) => value);
  const validIntervals = AGE_INTERVALS.map(({ value }) => value);
  const validVulnerabilityStates = Object.keys(APPROVAL_VULNERABILITY_STATES[PREVIOUSLY_EXISTING]);

  return rules
    .filter((rule) => rule.vulnerability_age)
    .some((rule) => {
      const {
        vulnerability_age: { value, operator, interval },
        vulnerability_states: states,
      } = rule;
      return (
        !validOperators.includes(operator) ||
        !isPositiveInteger(value) ||
        !validIntervals.includes(interval) ||
        !states?.length ||
        !states?.some((state) => validVulnerabilityStates.includes(state)) ||
        !Object.keys(rule.vulnerability_age).every((key) =>
          VULNERABILITY_AGE_ALLOWED_KEYS.includes(key),
        )
      );
    });
};

/**
 * Check if any rule has invalid branch type
 * @param rules list of rules with either branches or branch_type property
 * @returns {Boolean}
 */
export const invalidBranchType = (rules) => {
  if (!rules) return false;

  return rules.some(
    (rule) =>
      BRANCH_TYPE_KEY in rule && !VALID_SCAN_RESULT_BRANCH_TYPE_OPTIONS.includes(rule.branch_type),
  );
};

/**
 * Check if any rule has invalid values for required keys
 * @param {Array} rules
 * @returns {Boolean}
 */
export const hasInvalidRules = (rules) =>
  invalidScanners(rules) ||
  invalidSeverities(rules) ||
  invalidVulnerabilitiesAllowed(rules) ||
  invalidVulnerabilityStates(rules) ||
  invalidBranchType(rules) ||
  invalidVulnerabilityAge(rules) ||
  invalidVulnerabilityAttributes(rules);

/*
  Returns the config for a particular rule type
*/
export const getDefaultRule = (scanType) => {
  switch (scanType) {
    case SCAN_FINDING:
      return securityScanBuildRule();
    case LICENSE_FINDING:
      return licenseScanBuildRule();
    case ANY_MERGE_REQUEST:
      return anyMergeRequestBuildRule();
    default:
      return emptyBuildRule();
  }
};

const doesBranchExist = async ({ branch, projectId }) => {
  try {
    await Api.projectProtectedBranch(projectId, branch);
    return true;
  } catch {
    return false;
  }
};

export const getInvalidBranches = async ({ branches, projectId }) => {
  const uniqueBranches = [...new Set(branches)];
  const invalidBranches = [];

  for await (const branch of uniqueBranches) {
    if (!(await doesBranchExist({ branch, projectId }))) {
      invalidBranches.push(branch);
    }
  }

  return invalidBranches;
};

export const humanizeInvalidBranchesError = (branches) => {
  const sentence = [];
  if (branches.length > 1) {
    const lastBranch = branches.pop();
    sentence.push(branches.join(', '), s__('SecurityOrchestration| and '), lastBranch);
  } else {
    sentence.push(branches.join());
  }
  return sprintf(INVALID_PROTECTED_BRANCHES, { branches: sentence.join('') });
};
