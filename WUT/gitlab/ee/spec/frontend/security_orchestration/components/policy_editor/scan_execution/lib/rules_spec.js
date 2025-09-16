import {
  buildDefaultPipeLineRule,
  buildDefaultScheduleRule,
  handleBranchTypeSelect,
  hasPredefinedRuleStrategy,
  STRATEGIES_RULE_MAP,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/rules';
import {
  ALL_PROTECTED_BRANCHES,
  SPECIFIC_BRANCHES,
  PROJECT_DEFAULT_BRANCH,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  DEFAULT_CONDITION_STRATEGY,
  SCAN_EXECUTION_RULES_PIPELINE_KEY,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';

const ruleId = 'rule_0';
jest.mock('lodash/uniqueId', () => jest.fn().mockReturnValue(ruleId));

describe('buildDefaultPipeLineRule', () => {
  it('builds a pipeline rule', () => {
    expect(buildDefaultPipeLineRule()).toEqual({
      branches: ['*'],
      id: ruleId,
      type: 'pipeline',
    });
  });
});

describe('buildDefaultScheduleRule', () => {
  it('builds a schedule rule', () => {
    expect(buildDefaultScheduleRule()).toEqual({
      branches: [],
      cadence: '0 0 * * *',
      id: ruleId,
      type: 'schedule',
    });
  });
});

describe('handleBranchTypeSelect', () => {
  describe('when selecting SPECIFIC_BRANCHES', () => {
    it('returns rule with branches array and removes branch_type for pipeline rules', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branch_type: ALL_PROTECTED_BRANCHES.value,
      };

      const result = handleBranchTypeSelect({
        branchType: SPECIFIC_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result).toEqual({
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['*'],
      });
      expect(result.branch_type).toBeUndefined();
    });

    it('returns rule with empty branches array for non-pipeline rules', () => {
      const rule = {
        type: 'schedule',
        branch_type: ALL_PROTECTED_BRANCHES.value,
      };

      const result = handleBranchTypeSelect({
        branchType: SPECIFIC_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result).toEqual({
        type: 'schedule',
        branches: [],
      });
      expect(result.branch_type).toBeUndefined();
    });

    it('preserves other properties in the rule', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branch_type: ALL_PROTECTED_BRANCHES.value,
        actions: ['scan'],
        branch_exceptions: ['main'],
      };

      const result = handleBranchTypeSelect({
        branchType: SPECIFIC_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result).toEqual({
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['*'],
        actions: ['scan'],
        branch_exceptions: ['main'],
      });
    });
  });

  describe('when selecting a branch type other than SPECIFIC_BRANCHES', () => {
    it('returns rule with branch_type and removes branches property', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['feature/*'],
      };

      const result = handleBranchTypeSelect({
        branchType: ALL_PROTECTED_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result).toEqual({
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branch_type: ALL_PROTECTED_BRANCHES.value,
      });
      expect(result.branches).toBeUndefined();
    });

    it('preserves other properties in the rule', () => {
      const rule = {
        type: 'schedule',
        branches: ['feature/*'],
        actions: ['scan'],
        branch_exceptions: ['main'],
      };

      const result = handleBranchTypeSelect({
        branchType: PROJECT_DEFAULT_BRANCH.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result).toEqual({
        type: 'schedule',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        actions: ['scan'],
        branch_exceptions: ['main'],
      });
    });
  });

  describe('pipeline_sources handling', () => {
    it('removes pipeline_sources', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['feature/*'],
        pipeline_sources: ['web', 'api'],
      };

      const result = handleBranchTypeSelect({
        branchType: 'non-target-branch-type', // Not in TARGET_BRANCHES
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result.pipeline_sources).toBeUndefined();
    });
  });
});

describe('hasPredefinedRuleStrategy', () => {
  it('returns true when the rules match one of the strategies', () => {
    expect(hasPredefinedRuleStrategy(STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY])).toBe(true);
  });

  it('returns true when the rules match one of the strategies ignoring ids', () => {
    const OPTIMIZED_RULES_WITH_IDS = STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY].map(
      (rule, index) => ({
        ...rule,
        id: index.toString(),
      }),
    );
    expect(hasPredefinedRuleStrategy(OPTIMIZED_RULES_WITH_IDS)).toBe(true);
  });

  it('returns false when the rules include extra rules', () => {
    expect(
      hasPredefinedRuleStrategy([
        ...STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY],
        { type: 'pipeline', branch_type: 'protected' },
      ]),
    ).toBe(false);
  });

  it('returns false when the rules do not match one of the strategies', () => {
    expect(hasPredefinedRuleStrategy([{ type: 'pipeline', branch_type: 'protected' }])).toBe(false);
  });

  it('returns false when the rules do not match one of the strategies ignoring rule id', () => {
    expect(
      hasPredefinedRuleStrategy([{ type: 'pipeline', branch_type: 'protected', id: '1' }]),
    ).toBe(false);
  });

  it('returns false for empty rules', () => {
    expect(hasPredefinedRuleStrategy([])).toBe(false);
  });
});
