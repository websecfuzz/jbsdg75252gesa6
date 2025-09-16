import { uniqueId, get } from 'lodash';
import {
  ACCOUNTS,
  EXCEPTIONS_FULL_OPTIONS_MAP,
  SOURCE_BRANCH_PATTERNS,
  GROUPS,
  ROLES,
  TOKENS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';

export const createSourceBranchPatternObject = ({ id = '', source = {}, target = {} } = {}) => ({
  id: id || uniqueId('pattern_'),
  source,
  target,
});

export const createServiceAccountObject = ({ id = '', account = {}, tokens = [] } = {}) => ({
  id: id || uniqueId('account_'),
  account,
  tokens,
});
/**
 * Extract username from account
 * @param item
 * @returns {*}
 */
export const getUserName = (item) => get(item, 'account.username', '');

/**
 * validate that account has all required properties
 * @param item
 * @returns {boolean}
 */
export const isValidServiceAccount = (item) => item && Boolean(item.name) && Boolean(item.username);

/**
 * remove ids from items
 * @param items
 * @returns {*[]}
 */
export const removeIds = (items = []) => {
  return items.map(({ id, ...item }) => ({ ...item }));
};

export const renderOptionsList = ({
  approvalPolicyBranchExceptions = false,
  securityPoliciesBypassOptionsTokensAccounts = false,
  securityPoliciesBypassOptionsGroupRoles = false,
}) => {
  const allOptions = { ...EXCEPTIONS_FULL_OPTIONS_MAP };

  if (!approvalPolicyBranchExceptions) {
    delete allOptions[SOURCE_BRANCH_PATTERNS];
  }

  if (!securityPoliciesBypassOptionsTokensAccounts) {
    delete allOptions[ACCOUNTS];
    delete allOptions[TOKENS];
  }

  if (!securityPoliciesBypassOptionsGroupRoles) {
    delete allOptions[ROLES];
    delete allOptions[GROUPS];
  }

  return allOptions;
};

/**
 * Filter out invalid exceptions keys
 * @param keys
 * @returns {string[]};
 */
export const onlyValidKeys = (keys) => {
  const {
    approvalPolicyBranchExceptions,
    securityPoliciesBypassOptionsTokensAccounts,
    securityPoliciesBypassOptionsGroupRoles,
  } = window.gon?.features || {};

  const validKeys = Object.keys(
    renderOptionsList({
      approvalPolicyBranchExceptions,
      securityPoliciesBypassOptionsTokensAccounts,
      securityPoliciesBypassOptionsGroupRoles,
    }),
  );
  return keys.filter((key) => validKeys.includes(key));
};
