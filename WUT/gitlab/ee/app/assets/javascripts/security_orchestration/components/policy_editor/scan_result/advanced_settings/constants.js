import { s__ } from '~/locale';

export const CLOSED = 'closed';

export const OPEN = 'open';

export const UNBLOCK_RULES_KEY = 'unblock_rules_using_execution_policies';

export const UNBLOCK_RULES_TEXT = s__(
  'ScanResultPolicy|Make approval rules optional using execution policies',
);

export const NAME = 'name';
export const PATTERN = 'pattern';
export const SOURCE = 'source';
export const TARGET = 'target';

export const ROLES = 'roles';
export const GROUPS = 'groups';
export const ACCOUNTS = 'accounts';
export const TOKENS = 'access_tokens';
export const SOURCE_BRANCH_PATTERNS = 'branches';

export const EXCEPTIONS_FULL_OPTIONS_MAP = {
  [ROLES]: {
    header: s__('ScanResultPolicy|Roles'),
    subHeader: s__(
      'ScanResultPolicy|Select role exceptions. Choose which roles can bypass this policy.',
    ),
    description: s__(
      'ScanResultPolicy|Grant bypass permissions to users based on their organizational role or custom role assignments.',
    ),
    example: s__(
      'ScanResultPolicy|If your Security Engineer role needs to dismiss false positive findings from security scanners without requiring additional approvals, add the Security Engineer role to bypass security scan policies.',
    ),
  },
  [GROUPS]: {
    header: s__('ScanResultPolicy|Groups'),
    subHeader: s__(
      'ScanResultPolicy|Select group exceptions. Choose which groups can bypass this policy.',
    ),
    description: s__(
      'ScanResultPolicy|Allow entire teams or departments to bypass policies for their specialized workflows.',
    ),
    example: s__(
      'ScanResultPolicy|If your DevOps Team frequently needs to push infrastructure configuration changes that trigger policy violations but are pre-approved through your change management process, add the DevOps Team group to bypass infrastructure policies.',
    ),
  },
  [ACCOUNTS]: {
    header: s__('AccountTokens|Service Account'),
    subHeader: s__('ScanResultPolicy|Choose which service accounts can bypass this policy.'),
    description: s__(
      'ScanResultPolicy|Enable automated systems and bots to bypass policies for approved workflows.',
    ),
    example: s__(
      'ScanResultPolicy|If your dependabot@company.com service account automatically creates pull requests for dependency updates that may contain license compliance violations requiring manual review.',
    ),
  },
  [TOKENS]: {
    header: s__('ScanResultPolicy|Access Token'),
    subHeader: s__(
      'ScanResultPolicy|Select instance group or project level access tokens that can bypass this policy.',
    ),
    description: s__(
      "ScanResultPolicy|Allow specific automation tokens to bypass policies when service accounts aren't available.",
    ),
    example: s__(
      'ScanResultPolicy|If your CI/CD Pipeline Token needs to push automated version updates directly to main branch during release deployments, bypassing the normal merge request approval process.',
    ),
  },
  [SOURCE_BRANCH_PATTERNS]: {
    header: s__('SourceBranchPattern|Source Branch Patterns'),
    subHeader: s__(
      'ScanResultPolicy|Define branch patterns that can bypass policy requirements using wildcards and regex patterns. Use * for simple wildcards or regex patterns for advanced matching.',
    ),
    description: s__(
      'ScanResultPolicy|Allow specific types of branches to bypass policies based on naming conventions.',
    ),
    example: s__(
      'ScanResultPolicy|If you want to allow all hotfix branches to bypass approval requirements during production incidents, use “hotfix/*” to match branches like hotfix/payment-bug and hotfix/security-patch.',
    ),
  },
};

export const mapOptions = (options) =>
  Object.entries(options).map(([key, { header, description, example }]) => ({
    key,
    header,
    description,
    example,
  }));

export const EXCEPTION_FULL_OPTIONS = mapOptions(EXCEPTIONS_FULL_OPTIONS_MAP);
