import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapse, GlEmptyState } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import SettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_section.vue';
import FallbackAndEdgeCasesSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/fallback_and_edge_cases_section.vue';
import {
  CLOSED,
  OPEN,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import BotCommentAction from 'ee/security_orchestration/components/policy_editor/scan_result/action/bot_message_action.vue';
import {
  ACTION_LISTBOX_ITEMS,
  BLOCK_GROUP_BRANCH_MODIFICATION,
  BOT_MESSAGE_TYPE,
  WARN_TYPE,
  buildApprovalAction,
  buildBotMessageAction,
  DISABLED_BOT_MESSAGE_ACTION,
  SCAN_FINDING,
  getInvalidBranches,
  REQUIRE_APPROVAL_TYPE,
  DEFAULT_SCAN_RESULT_POLICY,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import EditorComponent from 'ee/security_orchestration/components/policy_editor/scan_result/editor_component.vue';
import PolicyExceptions from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions.vue';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import {
  mockDefaultBranchesScanResultManifest,
  mockDefaultBranchesScanResultObject,
  mockDefaultBranchesScanResultObjectWithoutBotAction,
  mockDeprecatedScanResultManifest,
  mockDeprecatedScanResultObject,
  mockWarnActionScanResultObject,
  mockFallbackInvalidScanResultManifest,
  mockDefaultBranchesScanResultManifestNewFormat,
  mockDefaultBranchesScanResultManifestWithWrapper,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import {
  APPROVAL_POLICY_DEFAULT_POLICY,
  APPROVAL_POLICY_DEFAULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS,
  ASSIGNED_POLICY_PROJECT,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  buildSettingsList,
  PERMITTED_INVALID_SETTINGS,
  BLOCK_BRANCH_MODIFICATION,
  PREVENT_PUSHING_AND_FORCE_PUSHING,
  PREVENT_APPROVAL_BY_AUTHOR,
  PREVENT_APPROVAL_BY_COMMIT_AUTHOR,
  REMOVE_APPROVALS_WITH_NEW_COMMIT,
  REQUIRE_PASSWORD_TO_APPROVE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import {
  policyBodyToYaml,
  removeIdsFromPolicy,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { SECURITY_POLICY_ACTIONS } from 'ee/security_orchestration/components/policy_editor/constants';
import ActionSection from 'ee/security_orchestration/components/policy_editor/scan_result/action/action_section.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/rule_section.vue';
import { mockLinkedSppItemsResponse } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { goToRuleMode } from '../policy_editor_helper';

jest.mock('lodash/uniqueId');

jest.mock('ee/security_orchestration/components/policy_editor/scan_result/lib', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/scan_result/lib'),
  getInvalidBranches: jest.fn().mockResolvedValue([]),
}));

describe('EditorComponent', () => {
  let wrapper;
  const defaultProjectPath = 'path/to/project';
  const policyEditorEmptyStateSvgPath = 'path/to/svg';
  const scanPolicyDocumentationPath = 'path/to/docs';

  const defaultGroups = [
    { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
  ];

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    return createMockApollo([[getSppLinkedProjectsGroups, handler]]);
  };

  const factory = ({
    propsData = {},
    provide = {},
    handler = mockLinkedSppItemsResponse(),
  } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        errorSources: [],
        selectedPolicyType: POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter,
        isCreating: false,
        isDeleting: false,
        isEditing: false,
        ...propsData,
      },
      provide: {
        disableScanPolicyUpdate: false,
        policyEditorEmptyStateSvgPath,
        namespaceId: 1,
        namespacePath: defaultProjectPath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        scanPolicyDocumentationPath,
        ...provide,
      },
    });
  };

  const factoryWithExistingPolicy = ({
    policy = {},
    provide = {},
    handler,
    hasActions = true,
    hasRules = true,
  } = {}) => {
    const existingPolicy = { ...mockDefaultBranchesScanResultObject };

    if (!hasActions) {
      delete existingPolicy.actions;
    }

    if (!hasRules) {
      delete existingPolicy.rules;
    }

    return factory({
      propsData: {
        assignedPolicyProject: ASSIGNED_POLICY_PROJECT,
        existingPolicy: { ...existingPolicy, ...policy },
        isEditing: true,
      },
      provide,
      handler,
    });
  };

  const findDisabledSection = (section) => wrapper.findByTestId(`disabled-${section}`);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findFallbackAndEdgeCasesSection = () => wrapper.findComponent(FallbackAndEdgeCasesSection);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findActionSection = () => wrapper.findComponent(ActionSection);
  const findAllActionSections = () => wrapper.findAllComponents(ActionSection);
  const findAddRuleButton = () => wrapper.findByTestId('add-rule');
  const findTooltip = () =>
    getBinding(wrapper.findByTestId('add-rule-wrapper').element, 'gl-tooltip');
  const findAllRuleSections = () => wrapper.findAllComponents(RuleSection);
  const findSettingsSection = () => wrapper.findComponent(SettingsSection);
  const findEmptyActionsAlert = () => wrapper.findByTestId('empty-actions-alert');
  const findScanFilterSelector = () => wrapper.findComponent(ScanFilterSelector);
  const findBotCommentAction = () => wrapper.findComponent(BotCommentAction);
  const findBotCommentActions = () => wrapper.findAllComponents(BotCommentAction);
  const findWarnAction = () => wrapper.findByTestId('warn-action');
  const findAdvancedSectionButton = () => wrapper.findByTestId('collapse-button');
  const findCollapseSection = () => wrapper.findComponent(GlCollapse);
  const findPolicyExceptions = () => wrapper.findComponent(PolicyExceptions);

  beforeEach(() => {
    getInvalidBranches.mockClear();
    uniqueId
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}0`))
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}1`))
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}2`));
  });

  afterEach(() => {
    uniqueId.mockRestore();
  });

  describe('rendering', () => {
    it.each`
      namespaceType              | policy
      ${NAMESPACE_TYPES.GROUP}   | ${APPROVAL_POLICY_DEFAULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS}
      ${NAMESPACE_TYPES.PROJECT} | ${APPROVAL_POLICY_DEFAULT_POLICY}
    `('should render default policy for a $namespaceType', ({ namespaceType, policy }) => {
      factory({ provide: { namespaceType } });
      expect(findPolicyEditorLayout().props('policy')).toStrictEqual(policy);
      expect(findPolicyEditorLayout().props('hasParsingError')).toBe(false);
      expect(findPolicyExceptions().exists()).toBe(false);
    });

    it.each`
      namespaceType              | manifest
      ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS}
      ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_RESULT_POLICY}
    `(
      'should use the correct default policy yaml for a $namespaceType',
      ({ namespaceType, manifest }) => {
        factory({ provide: { namespaceType } });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(manifest);
      },
    );

    it('displays the initial rule and add rule button', () => {
      factory();
      expect(findAllRuleSections()).toHaveLength(1);
      expect(findAddRuleButton().exists()).toBe(true);
    });

    describe('when a user is not an owner of the project', () => {
      it('displays the empty state with the appropriate properties', () => {
        factory({ provide: { disableScanPolicyUpdate: true } });

        const emptyState = findEmptyState();

        expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
        expect(emptyState.props('primaryButtonLink')).toMatch('scan-result-policy-editor');
        expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
      });
    });

    describe('existing policy', () => {
      it('displays an approval policy', () => {
        factoryWithExistingPolicy();
        expect(findEmptyActionsAlert().exists()).toBe(false);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
          mockDefaultBranchesScanResultManifestWithWrapper,
        );

        expect(findAllRuleSections()).toHaveLength(1);
        expect(findAllActionSections()).toHaveLength(1);
        expect(findBotCommentActions()).toHaveLength(1);
      });

      it('displays a scan result policy', () => {
        factoryWithExistingPolicy({ policy: mockDeprecatedScanResultObject });
        expect(findPolicyEditorLayout().props('hasParsingError')).toBe(false);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
          mockDeprecatedScanResultManifest,
        );
        expect(findAllRuleSections()).toHaveLength(1);
        expect(findAllActionSections()).toHaveLength(1);
        expect(findBotCommentActions()).toHaveLength(1);
      });
    });

    describe('warn action', () => {
      it('does not display the warn action without a warn action', () => {
        factory();
        expect(findWarnAction().exists()).toBe(false);
      });

      it('does not display the warn action with the feature flag off', () => {
        factoryWithExistingPolicy({ policy: mockWarnActionScanResultObject });
        expect(findWarnAction().exists()).toBe(false);
      });

      it('displays the warn action', () => {
        factoryWithExistingPolicy({
          provide: { glFeatures: { securityPolicyApprovalWarnMode: true } },
          policy: mockWarnActionScanResultObject,
        });
        expect(findWarnAction().exists()).toBe(true);
      });

      it('updates the policy actions to be empty on removal of warn mode', async () => {
        factoryWithExistingPolicy({
          provide: { glFeatures: { securityPolicyApprovalWarnMode: true } },
          policy: mockWarnActionScanResultObject,
        });
        await findWarnAction().vm.$emit('remove');
        expect(findWarnAction().exists()).toBe(false);
        expect(findAllActionSections()).toHaveLength(0);
      });

      it('replaces policy actions with a new action when warn mode action is present', async () => {
        factoryWithExistingPolicy({
          provide: { glFeatures: { securityPolicyApprovalWarnMode: true } },
          policy: mockWarnActionScanResultObject,
        });
        expect(findWarnAction().exists()).toBe(true);
        await findScanFilterSelector().vm.$emit('select', BOT_MESSAGE_TYPE);
        expect(findAllActionSections()).toHaveLength(0);
        expect(findWarnAction().exists()).toBe(false);
        expect(findBotCommentAction().exists()).toBe(true);
      });

      it('replaces policy actions with warn mode actions on addition', async () => {
        await factory({ provide: { glFeatures: { securityPolicyApprovalWarnMode: true } } });
        expect(findBotCommentAction().exists()).toBe(true);
        await findScanFilterSelector().vm.$emit('select', WARN_TYPE);
        expect(findBotCommentAction().exists()).toBe(false);
        expect(findAllActionSections()).toHaveLength(1);
        expect(findWarnAction().exists()).toBe(true);
      });
    });

    describe('advanced section', () => {
      beforeEach(async () => {
        await factory();
      });

      it('renders the collapse button with the correct text', () => {
        const collapseButton = findAdvancedSectionButton();
        expect(collapseButton.exists()).toBe(true);
        expect(collapseButton.text()).toContain('Advanced');
      });

      it('initializes with the collapse section closed', () => {
        expect(findCollapseSection().props('visible')).toBe(false);
        expect(findAdvancedSectionButton().props('icon')).toBe('chevron-right');
      });

      it('toggles the collapse section when the button is clicked', async () => {
        const collapseButton = findAdvancedSectionButton();
        await collapseButton.vm.$emit('click');
        expect(findCollapseSection().props('visible')).toBe(true);
        expect(collapseButton.props('icon')).toBe('chevron-down');
        await collapseButton.vm.$emit('click');
        expect(findCollapseSection().props('visible')).toBe(false);
        expect(collapseButton.props('icon')).toBe('chevron-right');
      });
    });
  });

  describe('rule mode updates', () => {
    describe('properties', () => {
      it.each`
        component         | oldValue     | newValue
        ${'name'}         | ${''}        | ${'new policy name'}
        ${'description'}  | ${''}        | ${'new description'}
        ${'enabled'}      | ${true}      | ${false}
        ${'policy_scope'} | ${undefined} | ${{ compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }] }}
      `('updates the $component property', ({ component, newValue, oldValue }) => {
        factory();
        expect(findPolicyEditorLayout().props('policy')[component]).toEqual(oldValue);
        findPolicyEditorLayout().vm.$emit('update-property', component, newValue);
        expect(findPolicyEditorLayout().props('policy')[component]).toEqual(newValue);
      });

      it('removes the policy scope property', async () => {
        const oldValue = {
          policy_scope: { compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }] },
        };

        factoryWithExistingPolicy({ policy: oldValue });
        expect(findPolicyEditorLayout().props('policy').policy_scope).toEqual(
          oldValue.policy_scope,
        );
        await findPolicyEditorLayout().vm.$emit('remove-property', 'policy_scope');
        expect(findPolicyEditorLayout().props('policy').policy_scope).toBe(undefined);
      });
    });

    describe('rule section', () => {
      it('adds a new rule', async () => {
        const rulesCount = 1;
        factory();
        expect(findAllRuleSections()).toHaveLength(rulesCount);
        await findAddRuleButton().vm.$emit('click');
        expect(findAllRuleSections()).toHaveLength(rulesCount + 1);
      });

      it('shows correct label for add rule button', () => {
        factory();
        expect(findAddRuleButton().text()).toBe('Add new rule');
        expect(findAddRuleButton().props('disabled')).toBe(false);
        expect(findTooltip().value.disabled).toBe(true);
      });

      it('disables add button when the limit of 5 rules has been reached', () => {
        const limit = 5;
        const { id, ...rule } = mockDefaultBranchesScanResultObject.rules[0];
        factoryWithExistingPolicy({ policy: { rules: [rule, rule, rule, rule, rule] } });
        expect(findAllRuleSections()).toHaveLength(limit);
        expect(findAddRuleButton().props('disabled')).toBe(true);
        expect(findTooltip().value).toMatchObject({
          disabled: false,
          title: 'You can add a maximum of 5 rules.',
        });
      });

      it('updates an existing rule', async () => {
        const newValue = {
          type: 'scan_finding',
          branches: [],
          scanners: [],
          vulnerabilities_allowed: 1,
          severity_levels: [],
          vulnerability_states: [],
        };
        factory();

        await findAllRuleSections().at(0).vm.$emit('changed', newValue);
        expect(findAllRuleSections().at(0).props('initRule')).toEqual(newValue);
        expect(findPolicyEditorLayout().props('policy').rules[0].vulnerabilities_allowed).toBe(1);
      });

      it('deletes the initial rule', async () => {
        const initialRuleCount = 1;
        factory();

        expect(findAllRuleSections()).toHaveLength(initialRuleCount);

        await findAllRuleSections().at(0).vm.$emit('remove', 0);

        expect(findAllRuleSections()).toHaveLength(initialRuleCount - 1);
      });
    });

    describe('action section', () => {
      describe('rendering', () => {
        describe.each`
          namespaceType              | manifest
          ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS}
          ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_RESULT_POLICY}
        `('$namespaceType', ({ namespaceType, manifest }) => {
          it('should use the correct default policy yaml for a $namespaceType', () => {
            factory({ provide: { namespaceType } });
            expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(manifest);
          });

          it('displays the approver action and the add action button on the group-level', () => {
            factory({ provide: { namespaceType } });
            expect(findActionSection().exists()).toBe(true);
            expect(findAllActionSections()).toHaveLength(1);
            expect(findBotCommentActions()).toHaveLength(1);
          });
        });

        describe('bot message action section', () => {
          it('does not display a bot message action section if there is a bot message action in the policy with `enabled: false`', () => {
            factoryWithExistingPolicy({
              policy: {
                ...mockDefaultBranchesScanResultObject,
                actions: [DISABLED_BOT_MESSAGE_ACTION],
              },
            });
            expect(findAllActionSections()).toHaveLength(0);
            expect(findScanFilterSelector().props('filters')).toEqual(ACTION_LISTBOX_ITEMS());
          });

          it('displays a bot message action section if there is no bot message action in the policy', () => {
            factoryWithExistingPolicy({
              policy: mockDefaultBranchesScanResultObjectWithoutBotAction,
            });
            expect(findBotCommentActions()).toHaveLength(1);
          });
        });
      });

      describe('add', () => {
        it('displays the rule selector with approver option, when all bot message is selected', () => {
          factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });
          expect(findScanFilterSelector().exists()).toBe(true);
          expect(
            findScanFilterSelector().props('customFilterTooltip')({ value: BOT_MESSAGE_TYPE }),
          ).toBe('Merge request approval policies allow a maximum 1 bot message action.');
          expect(
            findScanFilterSelector().props('shouldDisableFilter')({ value: REQUIRE_APPROVAL_TYPE }),
          ).toBe(false);
          expect(findScanFilterSelector().props('filters')).toEqual([
            { value: REQUIRE_APPROVAL_TYPE, text: 'Require Approvers' },
            { value: BOT_MESSAGE_TYPE, text: 'Send bot message' },
          ]);
        });

        it('shows the scan filter selector if there are action types not shown', async () => {
          factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });
          await findAllActionSections().at(0).vm.$emit('remove');
          expect(findScanFilterSelector().exists()).toBe(true);
          expect(
            findScanFilterSelector().props('customFilterTooltip')({ value: REQUIRE_APPROVAL_TYPE }),
          ).toBe('Merge request approval policies allow a maximum of 5 approver actions.');
          expect(findScanFilterSelector().props('filters')).toEqual([
            { text: 'Require Approvers', value: REQUIRE_APPROVAL_TYPE },
            { text: 'Send bot message', value: BOT_MESSAGE_TYPE },
          ]);
        });

        it('updates an existing bot message action to be `enabled: true` when a bot message action is added', async () => {
          factoryWithExistingPolicy({
            policy: {
              ...mockDefaultBranchesScanResultObject,
              actions: [DISABLED_BOT_MESSAGE_ACTION],
            },
          });
          const { id: disabledId, ...disabledAction } = DISABLED_BOT_MESSAGE_ACTION;
          expect(findPolicyEditorLayout().props('policy').actions).toEqual([
            expect.objectContaining(disabledAction),
          ]);
          await findScanFilterSelector().vm.$emit('select', BOT_MESSAGE_TYPE);
          expect(findAllActionSections()).toHaveLength(0);
          expect(findBotCommentActions()).toHaveLength(1);
          const { id, ...action } = buildBotMessageAction();
          expect(findPolicyEditorLayout().props('policy').actions).toEqual([
            expect.objectContaining(action),
          ]);
        });

        it('adds an action when there are no other actions in the policy', async () => {
          factoryWithExistingPolicy({ hasActions: false });
          expect(findAllActionSections()).toHaveLength(0);
          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(1);
        });

        it('adds multiple approval rules', async () => {
          factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });

          expect(findAllActionSections()).toHaveLength(1);
          expect(findBotCommentActions()).toHaveLength(1);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);

          expect(findAllActionSections()).toHaveLength(2);
          expect(findBotCommentActions()).toHaveLength(1);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);

          expect(findAllActionSections()).toHaveLength(3);
          expect(findBotCommentActions()).toHaveLength(1);
        });

        it('add maximum of 5 approval actions', async () => {
          factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });

          expect(findAllActionSections()).toHaveLength(1);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(2);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(3);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(4);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(5);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(5);
        });

        describe('multiple approval actions', () => {
          it('allows to add multiple approver actions', () => {
            factoryWithExistingPolicy({
              policy: mockDefaultBranchesScanResultObject,
            });

            expect(findScanFilterSelector().exists()).toBe(true);

            expect(
              findScanFilterSelector().props('shouldDisableFilter')({
                value: REQUIRE_APPROVAL_TYPE,
              }),
            ).toBe(false);
            expect(
              findScanFilterSelector().props('customFilterTooltip')({
                value: REQUIRE_APPROVAL_TYPE,
              }),
            ).toBe('Merge request approval policies allow a maximum of 5 approver actions.');
          });
        });
      });

      describe('remove', () => {
        it('removes the approver action', async () => {
          factory();
          expect(findAllActionSections()).toHaveLength(1);
          await findActionSection().vm.$emit('remove');
          expect(findAllActionSections()).toHaveLength(0);
          expect(findPolicyEditorLayout().props('policy').actions).not.toContainEqual(
            buildApprovalAction(),
          );
        });

        it('disables the bot message action', async () => {
          factory();
          expect(findAllActionSections()).toHaveLength(1);
          expect(findBotCommentActions()).toHaveLength(1);
          await findBotCommentAction().vm.$emit('changed', DISABLED_BOT_MESSAGE_ACTION);
          expect(findAllActionSections()).toHaveLength(1);
          expect(findBotCommentActions()).toHaveLength(0);
          expect(findPolicyEditorLayout().props('policy').actions).toContainEqual(
            DISABLED_BOT_MESSAGE_ACTION,
          );
        });

        it('removes the action approvers when the action is removed', async () => {
          factory();
          await findActionSection().vm.$emit(
            'changed',
            mockDefaultBranchesScanResultObject.actions[0],
          );
          await findAllActionSections().at(0).vm.$emit('remove');
          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);

          expect(removeIdsFromPolicy(findPolicyEditorLayout().props('policy')).actions).toEqual([
            { approvals_required: 1, type: REQUIRE_APPROVAL_TYPE },
            { type: BOT_MESSAGE_TYPE, enabled: true },
          ]);
        });
      });

      describe('update', () => {
        beforeEach(() => {
          factory();
        });

        it('updates policy action when edited', async () => {
          const UPDATED_ACTION = {
            approvals_required: 1,
            group_approvers_ids: [29],
            id: 'action_0',
            type: REQUIRE_APPROVAL_TYPE,
          };
          await findActionSection().vm.$emit('changed', UPDATED_ACTION);
          expect(findActionSection().props('initAction')).toEqual(UPDATED_ACTION);
        });

        it('creates an error when the action section emits one', async () => {
          await findActionSection().vm.$emit('error');
          expect(findDisabledSection('actions').props('disabled')).toBe(true);
        });
      });
    });
  });

  describe('yaml mode updates', () => {
    beforeEach(factory);

    it('updates the policy yaml and policy object when "update-yaml" is emitted', async () => {
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockDefaultBranchesScanResultManifest);
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
        mockDefaultBranchesScanResultManifest,
      );
      expect(removeIdsFromPolicy(findPolicyEditorLayout().props('policy'))).toMatchObject(
        removeIdsFromPolicy(mockDefaultBranchesScanResultObject),
      );
    });
  });

  describe('modifying a policy', () => {
    it.each`
      status                           | action                            | event              | factoryFn                    | yamlEditorValue
      ${'creating a new policy'}       | ${undefined}                      | ${'save-policy'}   | ${factory}                   | ${policyBodyToYaml(fromYaml({ manifest: DEFAULT_SCAN_RESULT_POLICY, type: POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter }))}
      ${'updating an existing policy'} | ${undefined}                      | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockDefaultBranchesScanResultManifestNewFormat}
      ${'deleting an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE} | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockDefaultBranchesScanResultManifestNewFormat}
    `('emits "save" when $status', async ({ action, event, factoryFn, yamlEditorValue }) => {
      factoryFn();
      findPolicyEditorLayout().vm.$emit(event);
      await waitForPromises();
      expect(wrapper.emitted('save')).toEqual([
        [{ action, isRuleMode: true, policy: yamlEditorValue }],
      ]);
    });

    it('passes down action errors', () => {
      const errorCause = {
        field: 'approvers_ids',
        message: 'Required approvals exceed eligible approvers.',
        title: 'Logic error',
      };
      factory({ propsData: { errorSources: [['action', '0', 'approvers_ids', [errorCause]]] } });
      expect(findActionSection().props('errors')).toEqual([errorCause]);
    });

    it('does not pass down non-action errors', () => {
      const errorSources = [['rule', '0', 'type']];
      factory({ propsData: { errorSources } });
      expect(findActionSection().props('errors')).toEqual([]);
      expect(findAllRuleSections().at(0).props('errorSources')).toEqual(errorSources);
    });
  });

  describe('yaml mode validation errors', () => {
    it('creates an error for invalid yaml', async () => {
      factory();
      await findPolicyEditorLayout().vm.$emit('update-yaml', 'invalid: manifest:');
      expect(findDisabledSection('actions').props('disabled')).toBe(true);
      expect(findDisabledSection('rules').props('disabled')).toBe(true);
      expect(findDisabledSection('settings').props('disabled')).toBe(true);
      expect(findFallbackAndEdgeCasesSection().props('hasError')).toBe(true);
    });
  });

  describe('branches being validated', () => {
    it.each`
      status                             | value       | output
      ${'invalid branches do not exist'} | ${[]}       | ${''}
      ${'invalid branches exist'}        | ${['main']} | ${'The following branches do not exist on this development project: main. Please review all protected branches to ensure the values are accurate before updating this policy.'}
    `('triggers error event with the correct content when $status', async ({ value, output }) => {
      const rule = { ...mockDefaultBranchesScanResultObject.rules[0], branches: ['main'] };
      getInvalidBranches.mockReturnValue(value);

      factoryWithExistingPolicy({ policy: { rules: [rule] } });

      await goToRuleMode(findPolicyEditorLayout);
      await waitForPromises();
      const errors = wrapper.emitted('error');

      expect(errors[errors.length - 1][0]).toEqual(output);
    });

    it('does not query protected branches when namespaceType is other than project', async () => {
      factoryWithExistingPolicy({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });

      await goToRuleMode(findPolicyEditorLayout);
      await waitForPromises();

      expect(getInvalidBranches).not.toHaveBeenCalled();
    });
  });

  describe('settings section', () => {
    const defaultProjectApprovalConfiguration = {
      [PREVENT_PUSHING_AND_FORCE_PUSHING]: true,
      [BLOCK_BRANCH_MODIFICATION]: true,
      [PREVENT_APPROVAL_BY_AUTHOR]: true,
      [PREVENT_APPROVAL_BY_COMMIT_AUTHOR]: true,
      [REMOVE_APPROVALS_WITH_NEW_COMMIT]: true,
      [REQUIRE_PASSWORD_TO_APPROVE]: false,
    };

    describe('settings', () => {
      beforeEach(() => {
        factory();
      });

      it('displays setting section', () => {
        expect(findSettingsSection().exists()).toBe(true);
        expect(findSettingsSection().props('settings')).toEqual(
          defaultProjectApprovalConfiguration,
        );
      });

      it('updates the policy when settings change', async () => {
        findAllRuleSections().at(0).vm.$emit('changed', { type: 'any_merge_request' });
        await findSettingsSection().vm.$emit('changed', {
          [PREVENT_APPROVAL_BY_AUTHOR]: false,
        });
        expect(findSettingsSection().props('settings')).toEqual({
          ...buildSettingsList(),
          [PREVENT_APPROVAL_BY_AUTHOR]: false,
        });
      });

      it('updates the policy when a change is emitted for pushingBranchesConfiguration', async () => {
        await findSettingsSection().vm.$emit('changed', {
          [PREVENT_PUSHING_AND_FORCE_PUSHING]: false,
        });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(
          `${PREVENT_PUSHING_AND_FORCE_PUSHING}: false`,
        );
      });

      it('updates the policy when a change is emitted for blockBranchModification', async () => {
        await findSettingsSection().vm.$emit('changed', {
          [BLOCK_BRANCH_MODIFICATION]: false,
        });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(
          `${BLOCK_BRANCH_MODIFICATION}: false`,
        );
      });

      it('updates the settings containing permitted invalid settings', () => {
        factoryWithExistingPolicy({ policy: { approval_settings: PERMITTED_INVALID_SETTINGS } });
        expect(findPolicyEditorLayout().props('policy')).toEqual(
          expect.objectContaining({ approval_settings: PERMITTED_INVALID_SETTINGS }),
        );
        findAllRuleSections().at(0).vm.$emit('changed', { type: SCAN_FINDING });
        expect(findPolicyEditorLayout().props('policy')).toEqual(
          expect.objectContaining({
            approval_settings: buildSettingsList(),
          }),
        );
      });
    });

    describe('empty policy alert', () => {
      const settingsPolicy = { approval_settings: { [BLOCK_BRANCH_MODIFICATION]: true } };
      const groupBranchModificationSettingsPolicy = {
        actions: [{ type: BOT_MESSAGE_TYPE, enabled: false }],
        approval_settings: {
          [BLOCK_GROUP_BRANCH_MODIFICATION]: { enabled: true, exceptions: [{ id: 1 }] },
        },
      };
      const disabledBotPolicy = { actions: [{ type: BOT_MESSAGE_TYPE, enabled: false }] };
      const disabledBotPolicyWithSettings = {
        approval_settings: { [BLOCK_BRANCH_MODIFICATION]: true },
        actions: [{ type: BOT_MESSAGE_TYPE, enabled: false }],
      };

      describe.each`
        title                                                              | policy                                   | hasActions | hasRules | hasAlert | alertVariant
        ${'has require approval action, settings and rules'}               | ${settingsPolicy}                        | ${true}    | ${true}  | ${false} | ${''}
        ${'has require approval action and rules but no settings'}         | ${{}}                                    | ${true}    | ${true}  | ${false} | ${''}
        ${'has settings but does not have actions, nor rules'}             | ${settingsPolicy}                        | ${false}   | ${false} | ${true}  | ${'warning'}
        ${'does not have actions or settings'}                             | ${{}}                                    | ${false}   | ${true}  | ${true}  | ${'warning'}
        ${'has disabled bot action and has settings'}                      | ${disabledBotPolicyWithSettings}         | ${true}    | ${true}  | ${true}  | ${'warning'}
        ${'has disabled bot action but does not have settings'}            | ${disabledBotPolicy}                     | ${true}    | ${true}  | ${true}  | ${'danger'}
        ${'has disabled bot action and group branch modification setting'} | ${groupBranchModificationSettingsPolicy} | ${true}    | ${true}  | ${true}  | ${'warning'}
      `('$title', ({ policy, hasActions, hasRules, hasAlert, alertVariant }) => {
        beforeEach(() => {
          factoryWithExistingPolicy({ policy, hasActions, hasRules });
        });

        it('renders the alert appropriately', () => {
          expect(findEmptyActionsAlert().exists()).toBe(hasAlert);
          if (hasAlert) {
            expect(findEmptyActionsAlert().props('variant')).toBe(alertVariant);
          }
        });
      });
    });

    describe('linked groups', () => {
      describe('graphql request', () => {
        it('fetches when namespace type is project', async () => {
          const mockRequestHandler = mockLinkedSppItemsResponse();
          factory({ handler: mockRequestHandler });
          await waitForPromises();
          expect(mockRequestHandler).toHaveBeenCalledWith({ fullPath: defaultProjectPath });
        });

        it('does not fetch when namespace type is group', async () => {
          const mockRequestHandler = mockLinkedSppItemsResponse();
          factory({
            provide: { namespaceType: NAMESPACE_TYPES.GROUP },
            handler: mockRequestHandler,
          });
          await waitForPromises();
          expect(mockRequestHandler).not.toHaveBeenCalled();
        });
      });

      it('updates the settings if groups are linked', async () => {
        factory({ handler: mockLinkedSppItemsResponse({ groups: defaultGroups }) });
        await waitForPromises();
        expect(findSettingsSection().props('settings')).toEqual({
          ...defaultProjectApprovalConfiguration,
          [BLOCK_GROUP_BRANCH_MODIFICATION]: true,
        });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(
          `${BLOCK_GROUP_BRANCH_MODIFICATION}: true`,
        );
      });

      it('does not update the settings if groups are not linked', async () => {
        factory({ handler: mockLinkedSppItemsResponse() });
        await waitForPromises();
        expect(findSettingsSection().props('settings')).toEqual(
          defaultProjectApprovalConfiguration,
        );
        expect(findPolicyEditorLayout().props('yamlEditorValue')).not.toContain(
          BLOCK_GROUP_BRANCH_MODIFICATION,
        );
      });

      it('does not change existing policy settings', async () => {
        const blockGroupBranchModificationSetting = {
          [BLOCK_GROUP_BRANCH_MODIFICATION]: {
            enabled: true,
            exceptions: [{ id: 1 }],
          },
        };
        factoryWithExistingPolicy({
          policy: {
            approval_settings: blockGroupBranchModificationSetting,
          },
          handler: mockLinkedSppItemsResponse({ groups: defaultGroups }),
        });
        await waitForPromises();
        expect(findSettingsSection().props('settings')).toMatchObject(
          blockGroupBranchModificationSetting,
        );
      });

      it('adds settings for an existing policy without settings', async () => {
        factoryWithExistingPolicy({
          handler: mockLinkedSppItemsResponse({ groups: defaultGroups }),
        });
        await waitForPromises();
        expect(findSettingsSection().props('settings')).toMatchObject({
          [BLOCK_GROUP_BRANCH_MODIFICATION]: true,
        });
      });
    });
  });

  describe('fallback and edge cases section', () => {
    it('renders the section without properties in the yaml', () => {
      factory();
      expect(findFallbackAndEdgeCasesSection().props('policy')).toMatchObject(
        expect.objectContaining({
          fallback_behavior: { fail: CLOSED },
        }),
      );
    });

    it('renders the fallback section with the fallback property in the yaml', () => {
      factoryWithExistingPolicy({
        policy: { fallback_behavior: { fail: OPEN } },
      });
      expect(findFallbackAndEdgeCasesSection().props('policy')).toMatchObject(
        expect.objectContaining({
          fallback_behavior: { fail: OPEN },
        }),
      );
    });

    it('handles update event', () => {
      factory();
      findFallbackAndEdgeCasesSection().vm.$emit('changed', 'fallback_behavior', {
        fail: OPEN,
      });
      expect(findFallbackAndEdgeCasesSection().props('policy')).toMatchObject(
        expect.objectContaining({
          fallback_behavior: { fail: OPEN },
        }),
      );
    });

    it('clears the fallback parsing error on update', async () => {
      factory();
      expect(findFallbackAndEdgeCasesSection().props('hasError')).toBe(false);
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockFallbackInvalidScanResultManifest);
      expect(findFallbackAndEdgeCasesSection().props('hasError')).toBe(true);
      await findFallbackAndEdgeCasesSection().vm.$emit('changed', 'fallback_behavior', {
        fail: OPEN,
      });
      expect(findFallbackAndEdgeCasesSection().props('hasError')).toBe(false);
    });
  });

  describe('bypass options', () => {
    it('renders bypass policy exceptions when ff is true', () => {
      factory({ provide: { glFeatures: { approvalPolicyBranchExceptions: true } } });

      expect(findPolicyExceptions().exists()).toBe(true);
    });
  });

  describe('new yaml format with type as a wrapper', () => {
    beforeEach(() => {
      factory();
    });

    it('renders default yaml in new format', () => {
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(DEFAULT_SCAN_RESULT_POLICY);
    });

    it('converts new policy format to old policy format when saved', async () => {
      findPolicyEditorLayout().vm.$emit('save-policy');
      await waitForPromises();

      expect(wrapper.emitted('save')).toEqual([
        [
          {
            action: undefined,
            isRuleMode: true,
            policy: `name: ''
description: ''
enabled: true
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 1
  - type: send_bot_message
    enabled: true
approval_settings:
  block_branch_modification: true
  prevent_pushing_and_force_pushing: true
  prevent_approval_by_author: true
  prevent_approval_by_commit_author: true
  remove_approvals_with_new_commit: true
  require_password_to_approve: false
fallback_behavior:
  fail: closed
type: approval_policy
`,
          },
        ],
      ]);
    });
  });
});
