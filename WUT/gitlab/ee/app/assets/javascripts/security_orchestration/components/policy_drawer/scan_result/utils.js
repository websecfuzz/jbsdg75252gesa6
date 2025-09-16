import { sprintf, s__, n__, __ } from '~/locale';

import {
  ANY_COMMIT,
  ANY_UNSIGNED_COMMIT,
  INVALID_RULE_MESSAGE,
  NO_RULE_MESSAGE,
  BRANCH_TYPE_KEY,
  HUMANIZED_BRANCH_TYPE_TEXT_DICT,
  SCAN_RESULT_BRANCH_TYPE_OPTIONS,
  GREATER_THAN_OPERATOR,
  LESS_THAN_OPERATOR,
  MATCH_ON_INCLUSION_LICENSE,
} from '../../policy_editor/constants';
import { createHumanizedScanners } from '../../policy_editor/utils';
import {
  NEEDS_TRIAGE_PLURAL,
  APPROVAL_VULNERABILITY_STATE_GROUPS,
  APPROVAL_VULNERABILITY_STATES_FLAT,
  FIX_AVAILABLE,
  FALSE_POSITIVE,
} from '../../policy_editor/scan_result/rule/scan_filters/constants';
import {
  ANY_MERGE_REQUEST,
  LICENSE_FINDING,
  LICENSE_STATES,
} from '../../policy_editor/scan_result/lib/rules';
import { groupSelectedVulnerabilityStates } from '../../policy_editor/scan_result/lib';
import { buildBranchExceptionsString, humanizedBranchExceptions } from '../utils';

/**
 * Create a human-readable list of strings, adding the necessary punctuation and conjunctions
 * @param {Array} items strings representing items to compose the final sentence
 * @param {String} singular string to be used for single items
 * @param {Boolean} hasTextBeforeItems
 * @param {String} plural string to be used for multiple items
 * @returns {String}
 */
const humanizeItems = ({ items, singular, plural, hasTextBeforeItems = false }) => {
  if (!items) {
    return '';
  }

  let noun = '';

  if (singular && plural) {
    noun = items.length > 1 ? plural : singular;
  }

  const finalSentence = [];

  if (hasTextBeforeItems && noun) {
    finalSentence.push(`${noun} `);
  }

  if (items.length === 1) {
    finalSentence.push(items.join(','));
  } else {
    const lastItem = items.pop();
    finalSentence.push(items.join(', '), s__('SecurityOrchestration| or '), lastItem);
  }

  if (!hasTextBeforeItems && noun) {
    finalSentence.push(` ${noun}`);
  }

  return finalSentence.join('');
};

/**
 * Create a human-readable version of the branches
 * @param {Array} branches
 * @returns {String}
 */
const humanizeBranches = (branches = []) => {
  const hasNoBranch = branches.length === 0;

  if (hasNoBranch) {
    return s__('SecurityOrchestration|any protected branch');
  }

  return sprintf(s__('SecurityOrchestration|the %{branches}'), {
    branches: humanizeItems({
      items: branches,
      singular: s__('SecurityOrchestration|branch'),
      plural: s__('SecurityOrchestration|branches'),
    }),
  });
};

const humanizeBranchType = (branchType) => {
  return sprintf(s__('SecurityOrchestration|targeting %{branchTypeText}'), {
    branchTypeText: HUMANIZED_BRANCH_TYPE_TEXT_DICT[branchType],
  });
};

/**
 * Create a human-readable version of the allowed vulnerabilities
 * @param {Number} vulnerabilitiesAllowed
 * @returns {String}
 */
const humanizeVulnerabilitiesAllowed = (vulnerabilitiesAllowed) =>
  vulnerabilitiesAllowed
    ? sprintf(s__('SecurityOrchestration|more than %{allowed}'), {
        allowed: vulnerabilitiesAllowed,
      })
    : s__('SecurityOrchestration|any');

/**
 * Create a translation map for vulnerability statuses,
 * applying replacements needed for human-readable version of vulnerability states
 * @returns {Object}
 */
const vulnerabilityStatusTranslationMap = {
  ...APPROVAL_VULNERABILITY_STATES_FLAT,
  new_needs_triage: NEEDS_TRIAGE_PLURAL,
  detected: NEEDS_TRIAGE_PLURAL,
};

/**
 * Create a human-readable version of the vulnerability states
 * @param {Array} vulnerabilitiesStates
 * @returns {String}
 */
const humanizeVulnerabilityStates = (vulnerabilitiesStates) => {
  if (!vulnerabilitiesStates.length) {
    return '';
  }

  const divider = __(', or ');
  const statesByGroup = groupSelectedVulnerabilityStates(vulnerabilitiesStates);
  const stateGroups = Object.keys(statesByGroup);

  return stateGroups
    .reduce((sentence, stateGroup) => {
      return [
        ...sentence,
        sprintf(s__('SecurityOrchestration|%{state} and %{statuses}'), {
          state: APPROVAL_VULNERABILITY_STATE_GROUPS[stateGroup].toLowerCase(),
          statuses: humanizeItems({
            items: statesByGroup[stateGroup].map((status) =>
              vulnerabilityStatusTranslationMap[status].toLowerCase(),
            ),
          }),
        }),
      ];
    }, [])
    .join(divider);
};

/**
 * Create a human-readable version of vulnerability attributes.
 * Supported attributes must be included in VULNERABILITY_ATTRIBUTES mapping.
 * @param {Object} vulnerabilityAttributes - Object containing applicable vulnerability attributes
 * @returns {String}
 */
const humanizeVulnerabilityAttributes = (vulnerabilityAttributes) => {
  const sentenceMap = {
    [FIX_AVAILABLE]: new Map([
      [true, s__('SecurityOrchestration|have a fix available')],
      [false, s__('SecurityOrchestration|have no fix available')],
    ]),
    [FALSE_POSITIVE]: new Map([
      [true, s__('SecurityOrchestration|are false positives')],
      [false, s__('SecurityOrchestration|are not false positives')],
    ]),
  };
  const sentence = Object.entries(vulnerabilityAttributes).map(([key, value]) => {
    return sentenceMap[key].get(value);
  });

  return sentence.join(__(' and '));
};

/**
 * Create a human-readable version of vulnerability age
 * @param {Object} vulnerabilityAge
 * @returns {String}
 */
const humanizeVulnerabilityAge = (vulnerabilityAge) => {
  const { value, operator } = vulnerabilityAge;

  const strMap = {
    day: (number) => n__('%d day', '%d days', number),
    week: (number) => n__('%d week', '%d weeks', number),
    month: (number) => n__('%d month', '%d months', number),
    year: (number) => n__('%d year', '%d years', number),
  };

  const baseStr = {
    [GREATER_THAN_OPERATOR]: sprintf(
      s__('SecurityOrchestration|Vulnerability age is greater than %{vulnerabilityAge}.'),
      { vulnerabilityAge: strMap[vulnerabilityAge.interval](value) },
    ),
    [LESS_THAN_OPERATOR]: sprintf(
      s__('SecurityOrchestration|Vulnerability age is less than %{vulnerabilityAge}.'),
      { vulnerabilityAge: strMap[vulnerabilityAge.interval](value) },
    ),
  };

  return baseStr[operator];
};

/**
 * Create a human-readable version of the scanners
 * @param {Array} scanners
 * @returns {String}
 */
const humanizeScanners = (scanners) => {
  const hasEmptyScanners = scanners.length === 0;

  if (hasEmptyScanners) {
    return s__('SecurityOrchestration|any security scanner finds');
  }

  return sprintf(s__('SecurityOrchestration|%{scanners}'), {
    scanners: humanizeItems({
      items: scanners,
      singular: s__('SecurityOrchestration|scanner finds'),
      plural: s__('SecurityOrchestration|scanners find'),
    }),
  });
};

const humanizeLicenseDetection = (licenseStates) => {
  const maxNumOfLicenseStates = Object.entries(LICENSE_STATES).length;

  if (licenseStates.length === maxNumOfLicenseStates) {
    return '';
  }

  return sprintf(s__('SecurityOrchestration| that is %{licenseState} and is'), {
    licenseState: LICENSE_STATES[licenseStates[0]].toLowerCase(),
  });
};

/**
 * Validate commits type
 * @param type commit type
 * @returns {*|string}
 */
const humanizeCommitType = (type) => {
  const stringMap = {
    [ANY_COMMIT]: s__('SecurityOrchestration| for any commits'),
    [ANY_UNSIGNED_COMMIT]: s__('SecurityOrchestration| for unsigned commits'),
  };

  return stringMap[type] || '';
};

const hasBranchType = (rule) => BRANCH_TYPE_KEY in rule;

const hasValidBranchType = (rule) => {
  if (!rule) return false;

  return (
    hasBranchType(rule) &&
    SCAN_RESULT_BRANCH_TYPE_OPTIONS()
      .map(({ value }) => value)
      .includes(rule.branch_type)
  );
};

/**
 * Create a human-readable version of the rule
 * @param {Object} rule {type: 'scan_finding', branch_type: 'protected', branches: ['master'], scanners: ['container_scanning'], vulnerabilities_allowed: 1, severity_levels: ['critical']}
 * @returns {Object} {summary: '', criteriaList: []}
 */
const humanizeRule = (rule) => {
  const humanizedValue = hasBranchType(rule)
    ? humanizeBranchType(rule.branch_type)
    : humanizeBranches(rule.branches);
  const targetingValue = hasBranchType(rule) ? '' : __('targeting ');

  if (hasBranchType(rule) && !hasValidBranchType(rule)) {
    return {
      summary: INVALID_RULE_MESSAGE,
    };
  }

  const branchExceptions = humanizedBranchExceptions(rule.branch_exceptions);
  const branchExceptionsString = buildBranchExceptionsString(rule.branch_exceptions);

  if (rule.type === LICENSE_FINDING) {
    const summaryText = rule[MATCH_ON_INCLUSION_LICENSE]
      ? s__(
          'SecurityOrchestration|When license scanner finds any license matching %{licenses}%{detection} in an open merge request %{targeting}%{branches}%{branchExceptionsString}',
        )
      : s__(
          'SecurityOrchestration|When license scanner finds any license except %{licenses}%{detection} in an open merge request %{targeting}%{branches}%{branchExceptionsString}',
        );

    return {
      summary: sprintf(summaryText, {
        detection: humanizeLicenseDetection(rule.license_states),
        branches: humanizedValue,
        targeting: targetingValue,
        branchExceptionsString: branchExceptions.length ? branchExceptionsString : '.',
      }),
      branchExceptions,
      licenses: rule.license_types,
      denyAllowList: rule.licenses || [],
    };
  }

  if (rule.type === ANY_MERGE_REQUEST) {
    const summaryText = s__(
      'SecurityOrchestration|For any merge request on %{branches}%{commitType}%{branchExceptionsString}',
    );

    return {
      summary: sprintf(summaryText, {
        branches: humanizedValue,
        commitType: humanizeCommitType(rule.commits),
        branchExceptionsString: branchExceptions.length ? branchExceptionsString : '.',
      }),
      branchExceptions,
    };
  }

  const criteriaList = [];

  const addCriteria = (predicate, compileCriteria) => {
    if (predicate) {
      criteriaList.push(compileCriteria());
    }
  };

  addCriteria(rule.severity_levels?.length, () =>
    sprintf(s__('SecurityOrchestration|Severity is %{severity}.'), {
      severity: humanizeItems({
        items: rule.severity_levels,
      }),
    }),
  );

  addCriteria(rule.vulnerability_states?.length, () =>
    sprintf(s__('SecurityOrchestration|Vulnerabilities are %{vulnerabilityStates}.'), {
      vulnerabilityStates: humanizeVulnerabilityStates(rule.vulnerability_states),
    }),
  );

  addCriteria(Object.keys(rule.vulnerability_age || {}).length, () =>
    humanizeVulnerabilityAge(rule.vulnerability_age),
  );

  addCriteria(Object.keys(rule.vulnerability_attributes || {}).length, () =>
    sprintf(s__('SecurityOrchestration|Vulnerabilities %{vulnerabilityStates}.'), {
      vulnerabilityStates: humanizeVulnerabilityAttributes(rule.vulnerability_attributes),
    }),
  );

  const criteriaMessage = s__('SecurityOrchestration| and all the following apply:');
  let criteriaEnding = '';

  if (!branchExceptions.length) {
    criteriaEnding = '.';
  }

  return {
    summary: sprintf(
      s__(
        'SecurityOrchestration|When %{scanners} %{vulnerabilitiesAllowed} %{vulnerability} in an open merge request %{targeting}%{branches}%{branchExceptionsString}%{criteriaApply}',
      ),
      {
        scanners: humanizeScanners(createHumanizedScanners(rule.scanners)),
        branches: humanizedValue,
        targeting: targetingValue,
        vulnerabilitiesAllowed: humanizeVulnerabilitiesAllowed(rule.vulnerabilities_allowed),
        vulnerability: n__('vulnerability', 'vulnerabilities', rule.vulnerabilities_allowed),
        branchExceptionsString: branchExceptions.length ? branchExceptionsString : '',
        criteriaApply:
          criteriaList.length && !branchExceptions.length ? criteriaMessage : criteriaEnding,
      },
    ),
    criteriaList,
    branchExceptions,
    criteriaMessage: criteriaList.length && branchExceptions.length ? criteriaMessage : '',
  };
};

/**
 * Create a human-readable version of the rules
 * @param rules {Array} [{type: 'scan_finding', branches: ['master'], scanners: ['container_scanning'], vulnerabilities_allowed: 1, severity_levels: ['critical']}]
 * @returns {Array} [{summary: '', criteriaList: []}]
 */
export const humanizeRules = (rules = []) => {
  const humanizedRules = rules.reduce((acc, curr) => {
    return [...acc, humanizeRule(curr)];
  }, []);
  return humanizedRules.length ? humanizedRules : [{ summary: NO_RULE_MESSAGE }];
};

/**
 * Map approver object to flat array
 * @param approvers
 * @returns {*[]}
 */
export const mapApproversToArray = (approvers) => {
  if (approvers === undefined) {
    return [];
  }

  const { allGroups = [], customRoles = [], roles = [], users = [] } = approvers || {};

  return [
    ...allGroups,
    ...customRoles,
    ...roles
      .map((role) => {
        return {
          GUEST: __('Guest'),
          REPORTER: __('Reporter'),
          DEVELOPER: __('Developer'),
          MAINTAINER: __('Maintainer'),
          OWNER: __('Owner'),
        }[role];
      })
      .filter(Boolean),
    ...users,
  ];
};
