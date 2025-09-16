import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlToggle } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import EditorComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/editor_component.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/rule_section.vue';
import ActionBuilder from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_action.vue';
import OverloadWarningModal from 'ee/security_orchestration/components/overload_warning_modal.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import getGroupProjectsCount from 'ee/security_orchestration/graphql/queries/get_group_project_count.query.graphql';
import {
  SCAN_EXECUTION_DEFAULT_POLICY_WITH_SCOPE,
  SCAN_EXECUTION_DEFAULT_POLICY,
  ASSIGNED_POLICY_PROJECT,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
  buildScannerAction,
  buildDefaultScheduleRule,
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_WITH_DEFAULT_VARIABLES,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import {
  mockDastScanExecutionManifest,
  mockDastScanExecutionObject,
  mockInvalidActionScanExecutionObject,
  mockInvalidRuleScanExecutionObject,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';

import {
  ACTION_SECTION_DISABLE_ERROR,
  CONDITION_SECTION_DISABLE_ERROR,
  SECURITY_POLICY_ACTIONS,
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  DEFAULT_CONDITION_STRATEGY,
  DEFAULT_SCANNER,
  SCAN_EXECUTION_PIPELINE_RULE,
  POLICY_ACTION_BUILDER_TAGS_ERROR_KEY,
  POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY,
  RUNNER_TAGS_PARSING_ERROR,
  DAST_SCANNERS_PARSING_ERROR,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { RULE_KEY_MAP } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/rules';
import {
  DEFAULT_SKIP_SI_CONFIGURATION,
  POLICY_TYPE_COMPONENT_OPTIONS,
} from 'ee/security_orchestration/components/constants';
import { policyBodyToYaml } from 'ee/security_orchestration/components/policy_editor/utils';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import OptimizedScanSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/optimized_scan_selector.vue';
import RuleStrategySelector from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/strategy_selector.vue';
import { goToYamlMode } from '../policy_editor_helper';

jest.mock('lodash/uniqueId');

describe('EditorComponent', () => {
  let wrapper;
  const defaultProjectPath = 'path/to/project';
  const policyEditorEmptyStateSvgPath = 'path/to/svg';
  const scanPolicyDocumentationPath = 'path/to/docs';

  const mockCountResponse = (count = 0) =>
    jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '1',
          projects: {
            count,
          },
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);

    return createMockApollo([[getGroupProjectsCount, handler]]);
  };

  const factory = ({ propsData = {}, provide = {}, handler = mockCountResponse() } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        selectedPolicyType: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        errorSources: [],
        isCreating: false,
        isDeleting: false,
        isEditing: false,
        ...propsData,
      },
      provide: {
        maxScanExecutionPolicyActions: 10,
        disableScanPolicyUpdate: false,
        policyEditorEmptyStateSvgPath,
        namespacePath: defaultProjectPath,
        namespaceType: NAMESPACE_TYPES.GROUP,
        scanPolicyDocumentationPath,
        ...provide,
      },
      stubs: {
        SkipCiSelector,
      },
    });
  };

  const factoryWithExistingPolicy = ({ policy = {}, provide = {} } = {}) => {
    return factory({
      propsData: {
        assignedPolicyProject: ASSIGNED_POLICY_PROJECT,
        existingPolicy: { ...mockDastScanExecutionObject, ...policy },
        isEditing: true,
      },
      provide,
    });
  };

  const findAddActionButton = () => wrapper.findByTestId('add-action');
  const findAddActionButtonWrapper = () => wrapper.findByTestId('add-action-wrapper');
  const findAddRuleButton = () => wrapper.findByTestId('add-rule');
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findActionBuilder = () => wrapper.findComponent(ActionBuilder);
  const findAllActionBuilders = () => wrapper.findAllComponents(ActionBuilder);
  const findRuleSection = () => wrapper.findComponent(RuleSection);
  const findAllRuleSections = () => wrapper.findAllComponents(RuleSection);
  const findOverloadWarningModal = () => wrapper.findComponent(OverloadWarningModal);
  const findDisabledAction = () => wrapper.findByTestId('disabled-action');
  const findDisabledRule = () => wrapper.findByTestId('disabled-rule');
  const findSkipCiSelector = () => wrapper.findComponent(SkipCiSelector);
  const findActionBuilderDefaultConfig = () => wrapper.findByTestId('default-action-config');
  const findActionBuilderDefaultConfigRadioButton = () =>
    wrapper.findByTestId('default-action-config-radio-button');
  const findActionBuilderCustomConfig = () => wrapper.findByTestId('custom-action-config');
  const findActionBuilderCustomConfigRadioButton = () =>
    wrapper.findByTestId('default-action-config-radio-button');
  const findOptimizedScanSelector = () => wrapper.findComponent(OptimizedScanSelector);
  const findRuleStrategySelector = () => wrapper.findComponent(RuleStrategySelector);
  const findConfigurationSelection = () => wrapper.findByTestId('configuration-selection');

  const selectScheduleRule = async () => {
    await findRuleSection().vm.$emit('changed', buildDefaultScheduleRule());
  };

  beforeEach(() => {
    uniqueId.mockImplementation(jest.fn((prefix) => `${prefix}0`));
  });

  describe('default', () => {
    beforeEach(() => {
      factory();
    });
    describe('scope', () => {
      it.each`
        namespaceType              | manifest
        ${NAMESPACE_TYPES.GROUP}   | ${SCAN_EXECUTION_DEFAULT_POLICY_WITH_SCOPE}
        ${NAMESPACE_TYPES.PROJECT} | ${SCAN_EXECUTION_DEFAULT_POLICY}
      `('should render default policy for a $namespaceType', ({ namespaceType, manifest }) => {
        factory({ provide: { namespaceType } });

        expect(findPolicyEditorLayout().props('policy')).toEqual(manifest);
        expect(findSkipCiSelector().exists()).toBe(true);
      });
    });

    it('should render correctly', () => {
      expect(findDisabledAction().props()).toEqual({
        disabled: false,
        error: ACTION_SECTION_DISABLE_ERROR,
      });
      expect(findDisabledRule().props()).toEqual({
        disabled: false,
        error: CONDITION_SECTION_DISABLE_ERROR,
      });
    });
  });

  describe('modifying a policy', () => {
    it.each`
      status                           | action                            | event              | factoryFn                    | yamlEditorValue
      ${'creating a new policy'}       | ${undefined}                      | ${'save-policy'}   | ${factory}                   | ${policyBodyToYaml(fromYaml({ manifest: DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_WITH_DEFAULT_VARIABLES, type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter }))}
      ${'updating an existing policy'} | ${undefined}                      | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockDastScanExecutionManifest}
      ${'deleting an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE} | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockDastScanExecutionManifest}
    `('emits "save" when $status', async ({ action, event, factoryFn, yamlEditorValue }) => {
      factoryFn();
      findPolicyEditorLayout().vm.$emit(event);
      await waitForPromises();
      expect(wrapper.emitted('save')).toEqual([[{ action, policy: yamlEditorValue }]]);
    });
  });

  describe('when a user is not an owner of the project', () => {
    it('displays the empty state with the appropriate properties', async () => {
      factory({ provide: { disableScanPolicyUpdate: true } });
      await nextTick();
      const emptyState = findEmptyState();

      expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
      expect(emptyState.props('primaryButtonLink')).toMatch('scan-execution-policy-editor');
      expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
    });
  });

  describe('yaml mode', () => {
    beforeEach(factory);

    it('updates the yaml and policy object when "update-yaml" is emitted', async () => {
      const newManifest = `name: test
enabled: true`;

      expect(findPolicyEditorLayout().props()).toMatchObject({
        parsingError: '',
        policy: fromYaml({
          manifest: DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }),
        yamlEditorValue: DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_WITH_DEFAULT_VARIABLES,
      });
      findPolicyEditorLayout().vm.$emit('update-yaml', newManifest);
      await nextTick();
      expect(findPolicyEditorLayout().props()).toMatchObject({
        parsingError: '',
        policy: expect.objectContaining({ enabled: true }),
        yamlEditorValue: newManifest,
      });
    });

    describe('properties', () => {
      it.each`
        component        | oldValue | newValue
        ${'name'}        | ${''}    | ${'new policy name'}
        ${'description'} | ${''}    | ${'new description'}
        ${'enabled'}     | ${true}  | ${false}
      `('updates the $component property', async ({ component, newValue, oldValue }) => {
        expect(findPolicyEditorLayout().props('policy')[component]).toBe(oldValue);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toMatch(
          `${component}: ${oldValue}`,
        );

        findPolicyEditorLayout().vm.$emit('update-property', component, newValue);
        await nextTick();

        expect(findPolicyEditorLayout().props('policy')[component]).toBe(newValue);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toMatch(
          `${component}: ${newValue}`,
        );
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

        expect(findSkipCiSelector().findComponent(GlToggle).props('value')).toBe(
          !DEFAULT_SKIP_SI_CONFIGURATION.allowed,
        );
      });
    });
  });

  describe('rule builder', () => {
    beforeEach(() => {
      uniqueId.mockRestore();
    });

    it('should add new rule', async () => {
      factory();

      const initialValue = [RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE]()];
      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(initialValue);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).rules,
      ).toStrictEqual(initialValue);
      expect(findAllRuleSections()).toHaveLength(1);

      findAddRuleButton().vm.$emit('click');
      await nextTick();

      const finalValue = [
        RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE](),
        RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE](),
      ];
      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(finalValue);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).rules,
      ).toStrictEqual(finalValue);
      expect(findAllRuleSections()).toHaveLength(2);
    });

    it('should add a new rule if the rule property does not exist', async () => {
      factory({ propsData: { existingPolicy: { name: 'test' }, isEditing: true } });
      expect(findAllRuleSections()).toHaveLength(0);
      findAddRuleButton().vm.$emit('click');
      await nextTick();
      expect(findAllRuleSections()).toHaveLength(1);
    });

    it('should update rule', async () => {
      factory();
      const initialValue = [RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE]()];
      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(initialValue);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).rules,
      ).toStrictEqual(initialValue);

      const finalValue = [{ ...RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE](), branches: ['main'] }];
      findRuleSection().vm.$emit('changed', finalValue[0]);
      await nextTick();

      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(finalValue);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).rules,
      ).toStrictEqual(finalValue);
    });

    it('should remove rule', async () => {
      factory();
      findAddRuleButton().vm.$emit('click');
      await nextTick();

      expect(findAllRuleSections()).toHaveLength(2);
      expect(findPolicyEditorLayout().props('policy').rules).toHaveLength(2);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).rules,
      ).toHaveLength(2);

      findRuleSection().vm.$emit('remove', 1);
      await nextTick();

      expect(findAllRuleSections()).toHaveLength(1);
      expect(findPolicyEditorLayout().props('policy').rules).toHaveLength(1);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).rules,
      ).toHaveLength(1);
    });
  });

  describe('action builder', () => {
    const glFeatures = { flexibleScanExecutionPolicy: true };

    beforeEach(() => {
      uniqueId.mockRestore();
      window.gon = { features: glFeatures };
    });

    afterAll(() => {
      window.gon = { features: {} };
    });

    describe('default', () => {
      it('shows default and custom selections', () => {
        factory({
          provide: { glFeatures },
        });
        expect(findConfigurationSelection().exists()).toBe(true);
      });

      it('checks optimized scanner by default', () => {
        factory({
          provide: { glFeatures },
        });
        expect(findActionBuilderDefaultConfigRadioButton().props('checked')).toBe('default');
        expect(findActionBuilderDefaultConfigRadioButton().attributes().disabled).toBe(undefined);
      });
    });

    describe('default configuration', () => {
      it('does not show custom configuration section', () => {
        factory({
          provide: { glFeatures },
        });
        expect(findActionBuilderDefaultConfig().exists()).toBe(true);
        expect(findActionBuilderCustomConfig().exists()).toBe(false);
      });

      describe('rule strategy selector', () => {
        it('updates the rules when a change is emitted', async () => {
          const rules = [{ branch_type: 'all' }];
          factory({
            provide: { glFeatures },
          });
          expect(findRuleStrategySelector().props('strategy')).toBe(DEFAULT_CONDITION_STRATEGY);
          await findRuleStrategySelector().vm.$emit('changed', {
            strategy: 'any',
            rules,
          });
          expect(findRuleStrategySelector().props('strategy')).toBe('any');
          expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(rules);
        });
      });

      describe('optimized scan selector', () => {
        it('renders optimized scan selector', () => {
          factory({
            provide: { glFeatures },
          });
          expect(findOptimizedScanSelector().exists()).toBe(true);
          expect(findOptimizedScanSelector().props()).toEqual({
            disabled: false,
            actions: [expect.objectContaining({ scan: 'secret_detection', template: 'latest' })],
          });
        });

        it('adds new action when selected', async () => {
          factory({
            provide: { glFeatures },
          });
          await findOptimizedScanSelector().vm.$emit('change', {
            scanner: 'sast',
            enabled: true,
          });
          const finalValue = [
            buildScannerAction({
              scanner: DEFAULT_SCANNER,
              isOptimized: true,
              withDefaultVariables: true,
            }),
            buildScannerAction({ scanner: 'sast', isOptimized: true, withDefaultVariables: true }),
          ];
          expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(finalValue);
          expect(
            fromYaml({
              manifest: findPolicyEditorLayout().props('yamlEditorValue'),
              type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
            }).actions,
          ).toStrictEqual(finalValue);
        });

        it('removes action when deselected', async () => {
          factory({
            provide: { glFeatures },
          });
          await findOptimizedScanSelector().vm.$emit('change', {
            scanner: 'secret_detection',
            enabled: false,
          });
          expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual([]);
          expect(
            fromYaml({
              manifest: findPolicyEditorLayout().props('yamlEditorValue'),
              type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
            }).actions,
          ).toStrictEqual([]);
        });

        it('is disabled when the policy is incompatible', async () => {
          factory({
            provide: { glFeatures },
          });

          // Switch to custom config first
          await findActionBuilderCustomConfigRadioButton().vm.$emit('input');

          // Add a DAST scan action, but there are many reasons the policy may be invalid for
          // optimized scans. See the getConfiguration method in
          // ee/app/assets/javascripts/security_orchestration/components/policy_editor/scan_execution/lib/index.js
          // for more info
          const dastAction = { scan: 'dast' };
          findActionBuilder().vm.$emit('changed', dastAction);
          await nextTick();

          // Switch to YAML mode and back to rule mode to trigger recalculation
          await findPolicyEditorLayout().vm.$emit('editor-mode-changed', EDITOR_MODE_YAML);
          await findPolicyEditorLayout().vm.$emit('editor-mode-changed', EDITOR_MODE_RULE);

          expect(findActionBuilderDefaultConfigRadioButton().attributes().disabled).toBe('true');
        });
      });
    });

    describe('custom configuration', () => {
      const newActions = [
        {
          scan: 'secret_detection',
          template: 'latest',
          variables: { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' },
        },
      ];
      it('does not show default configuration section', async () => {
        factory({
          provide: { glFeatures },
        });
        await findActionBuilderCustomConfigRadioButton().vm.$emit('input');
        expect(findActionBuilderDefaultConfig().exists()).toBe(false);
        expect(findActionBuilderCustomConfig().exists()).toBe(true);
      });

      it('adds new action', async () => {
        factory({ provide: { glFeatures } });
        await findActionBuilderCustomConfigRadioButton().vm.$emit('input');

        expect(findPolicyEditorLayout().props('policy').actions).toEqual(
          expect.objectContaining(newActions),
        );
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
          }).actions,
        ).toEqual(expect.objectContaining(newActions));

        findAddActionButton().vm.$emit('click');
        await nextTick();

        const finalValue = [
          buildScannerAction({
            scanner: DEFAULT_SCANNER,
            isOptimized: true,
            withDefaultVariables: true,
          }),
          buildScannerAction({ scanner: DEFAULT_SCANNER, withDefaultVariables: true }),
        ];

        expect(findPolicyEditorLayout().props('policy').actions).toEqual(finalValue);
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
          }).actions,
        ).toEqual(finalValue);
      });

      it('adds a new action if the action property does not exist', async () => {
        factory({
          propsData: { existingPolicy: { name: 'test' }, isEditing: true },
          provide: { glFeatures },
        });
        await findActionBuilderCustomConfigRadioButton().vm.$emit('input');

        expect(findAllActionBuilders()).toHaveLength(0);

        findAddActionButton().vm.$emit('click');
        await nextTick();

        expect(findAddActionButtonWrapper().attributes('title')).toBe('');
        expect(findAllActionBuilders()).toHaveLength(1);
      });

      it('updates action', async () => {
        factory({ provide: { glFeatures } });
        await findActionBuilderCustomConfigRadioButton().vm.$emit('input');

        const initialValue = [
          buildScannerAction({
            scanner: DEFAULT_SCANNER,
            withDefaultVariables: true,
            isOptimized: true,
          }),
        ];

        expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(initialValue);
        expect(findPolicyEditorLayout().props('policy').actions).toEqual(
          expect.objectContaining(newActions),
        );
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
          }).actions,
        ).toEqual(expect.objectContaining(newActions));

        const finalValue = [buildScannerAction({ scanner: 'sast', withDefaultVariables: true })];
        findActionBuilder().vm.$emit('changed', finalValue[0]);
        await nextTick();

        expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(finalValue);
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
          }).actions,
        ).toStrictEqual(finalValue);
      });

      it('removes action', async () => {
        factory({ provide: { glFeatures } });
        await findActionBuilderCustomConfigRadioButton().vm.$emit('input');
        findAddActionButton().vm.$emit('click');
        await nextTick();

        expect(findAllActionBuilders()).toHaveLength(2);
        expect(findPolicyEditorLayout().props('policy').actions).toHaveLength(2);
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
          }).actions,
        ).toHaveLength(2);

        findActionBuilder().vm.$emit('remove', 1);
        await nextTick();

        expect(findAllActionBuilders()).toHaveLength(1);
        expect(findPolicyEditorLayout().props('policy').actions).toHaveLength(1);
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
          }).actions,
        ).toHaveLength(1);
      });

      it('limits number of actions', async () => {
        const MAX_ACTIONS = 3;
        factory({
          provide: {
            maxScanExecutionPolicyActions: MAX_ACTIONS,
            glFeatures,
          },
        });
        await findActionBuilderCustomConfigRadioButton().vm.$emit('input');

        expect(findAddActionButton().attributes().disabled).toBeUndefined();
        expect(findAllActionBuilders()).toHaveLength(1);

        await findAddActionButton().vm.$emit('click');
        await findAddActionButton().vm.$emit('click');

        expect(findAllActionBuilders()).toHaveLength(MAX_ACTIONS);
        expect(findAddActionButton().attributes().disabled).toBe('true');
        expect(findAddActionButtonWrapper().attributes('title')).toBe(
          'Policy has reached the maximum of 3 actions',
        );
        expect(findAllActionBuilders()).toHaveLength(3);
      });
    });
  });

  describe('action builder without flexibleScanExecutionPolicy feature flag', () => {
    beforeEach(() => {
      uniqueId.mockRestore();
    });

    it('does not show configuration selection', () => {
      factory();
      expect(findConfigurationSelection().exists()).toBe(false);
    });

    it('should add new action', async () => {
      factory();
      const initialValue = [
        buildScannerAction({ scanner: DEFAULT_SCANNER, withDefaultVariables: true }),
      ];
      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(initialValue);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).actions,
      ).toStrictEqual(initialValue);

      findAddActionButton().vm.$emit('click');
      await nextTick();

      const finalValue = [
        buildScannerAction({ scanner: DEFAULT_SCANNER, withDefaultVariables: true }),
        buildScannerAction({ scanner: DEFAULT_SCANNER, withDefaultVariables: true }),
      ];

      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(finalValue);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).actions,
      ).toStrictEqual(finalValue);
    });

    it('should add a new action if the action property does not exist', async () => {
      factory({ propsData: { existingPolicy: { name: 'test' }, isEditing: true } });
      expect(findAllActionBuilders()).toHaveLength(0);
      findAddActionButton().vm.$emit('click');
      await nextTick();
      expect(findAddActionButtonWrapper().attributes('title')).toBe('');
      expect(findAllActionBuilders()).toHaveLength(1);
    });

    it('should update action', async () => {
      factory();
      const initialValue = [
        buildScannerAction({ scanner: DEFAULT_SCANNER, withDefaultVariables: true }),
      ];
      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(initialValue);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).actions,
      ).toStrictEqual(initialValue);

      const finalValue = [buildScannerAction({ scanner: 'sast', withDefaultVariables: true })];
      findActionBuilder().vm.$emit('changed', finalValue[0]);
      await nextTick();

      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(finalValue);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).actions,
      ).toStrictEqual(finalValue);
    });

    it('should remove action', async () => {
      factory();
      findAddActionButton().vm.$emit('click');
      await nextTick();

      expect(findAllActionBuilders()).toHaveLength(2);
      expect(findPolicyEditorLayout().props('policy').actions).toHaveLength(2);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).actions,
      ).toHaveLength(2);

      findActionBuilder().vm.$emit('remove', 1);
      await nextTick();

      expect(findAllActionBuilders()).toHaveLength(1);
      expect(findPolicyEditorLayout().props('policy').actions).toHaveLength(1);
      expect(
        fromYaml({
          manifest: findPolicyEditorLayout().props('yamlEditorValue'),
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
        }).actions,
      ).toHaveLength(1);
    });

    it('should limit number of actions', async () => {
      factory({
        provide: {
          maxScanExecutionPolicyActions: 3,
        },
      });

      expect(findAddActionButton().attributes().disabled).toBeUndefined();
      expect(findAllActionBuilders()).toHaveLength(1);

      await findAddActionButton().vm.$emit('click');
      await findAddActionButton().vm.$emit('click');
      await findAddActionButton().vm.$emit('click');

      expect(findAddActionButton().attributes().disabled).toBe('true');
      expect(findAddActionButtonWrapper().attributes('title')).toBe(
        'Policy has reached the maximum of 3 actions',
      );
      expect(findAllActionBuilders()).toHaveLength(3);
    });
  });

  describe('parsing errors', () => {
    it.each`
      name               | errorKey                                         | error
      ${'tags'}          | ${POLICY_ACTION_BUILDER_TAGS_ERROR_KEY}          | ${RUNNER_TAGS_PARSING_ERROR}
      ${'DAST profiles'} | ${POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY} | ${DAST_SCANNERS_PARSING_ERROR}
    `('disables action section when parsing of $name fails', async ({ errorKey, error }) => {
      factory();
      findActionBuilder().vm.$emit('parsing-error', errorKey);
      await nextTick();
      expect(findDisabledAction().props()).toEqual({ disabled: true, error });
      expect(findDisabledRule().props()).toEqual({
        disabled: false,
        error: CONDITION_SECTION_DISABLE_ERROR,
      });
    });

    it('disables action section for invalid action', () => {
      factory({
        propsData: { existingPolicy: mockInvalidActionScanExecutionObject, isEditing: true },
      });
      expect(findDisabledAction().props()).toEqual({
        disabled: true,
        error: ACTION_SECTION_DISABLE_ERROR,
      });
      expect(findDisabledRule().props()).toEqual({
        disabled: false,
        error: CONDITION_SECTION_DISABLE_ERROR,
      });
    });

    it('does not affect rule section errors', async () => {
      factory({
        propsData: { existingPolicy: mockInvalidRuleScanExecutionObject, isEditing: true },
      });
      expect(findDisabledRule().props()).toEqual({
        disabled: true,
        error: CONDITION_SECTION_DISABLE_ERROR,
      });
      findActionBuilder().vm.$emit('parsing-error', POLICY_ACTION_BUILDER_TAGS_ERROR_KEY);
      await nextTick();
      expect(findDisabledRule().props()).toEqual({
        disabled: true,
        error: CONDITION_SECTION_DISABLE_ERROR,
      });
    });
  });

  describe('performance warning modal', () => {
    describe('group', () => {
      describe('performance threshold not reached', () => {
        beforeEach(() => {
          factory();
        });

        it('saves policy when performance threshold is not reached', async () => {
          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(wrapper.emitted('save')[0]).toHaveLength(1);
        });

        it('saves policy when performance threshold is not reached and schedule rule is selected', async () => {
          await selectScheduleRule();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(wrapper.emitted('save')[0]).toHaveLength(1);
        });
      });

      it('does not show the warning when performance threshold is reached but no schedule rules were selected', async () => {
        factory({
          handler: mockCountResponse(1001),
        });
        await waitForPromises();

        findPolicyEditorLayout().vm.$emit('save-policy');
        await waitForPromises();

        expect(findOverloadWarningModal().props('visible')).toBe(false);
        expect(wrapper.emitted('save')[0]).toHaveLength(1);
      });

      describe('performance threshold reached', () => {
        beforeEach(async () => {
          factory({
            handler: mockCountResponse(1001),
          });

          await waitForPromises();
        });

        it('shows the warning when performance threshold is reached but schedule rules were selected', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(wrapper.emitted('save')).toBeUndefined();
        });

        it('dismisses the warning without saving the policy', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(wrapper.emitted('save')).toBeUndefined();

          await findOverloadWarningModal().vm.$emit('cancel-submit');

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(wrapper.emitted('save')).toBeUndefined();
        });

        it('dismisses the warning and saves the policy', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(wrapper.emitted('save')).toBeUndefined();

          await findOverloadWarningModal().vm.$emit('confirm-submit');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(wrapper.emitted('save')[0]).toHaveLength(1);
          expect(wrapper.emitted('save')[0][0]).toMatchObject({ action: undefined });
        });

        it('dismisses the warning and deletes the policy', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('remove-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(wrapper.emitted('save')).toBeUndefined();

          await findOverloadWarningModal().vm.$emit('confirm-submit');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(wrapper.emitted('save')[0]).toHaveLength(1);
          expect(wrapper.emitted('save')[0][0]).toMatchObject({
            action: SECURITY_POLICY_ACTIONS.REMOVE,
          });
        });

        it('dismisses the warning without deleting the policy and then edits it', async () => {
          await selectScheduleRule();
          await waitForPromises();
          findPolicyEditorLayout().vm.$emit('remove-policy');
          await waitForPromises();
          await findOverloadWarningModal().vm.$emit('cancel-submit');
          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();
          await findOverloadWarningModal().vm.$emit('confirm-submit');
          await waitForPromises();

          expect(wrapper.emitted('save')[0]).toHaveLength(1);
          expect(wrapper.emitted('save')[0][0]).toMatchObject({ action: undefined });
        });

        it('also shows warning modal in yaml mode', async () => {
          await selectScheduleRule();
          await waitForPromises();

          goToYamlMode(findPolicyEditorLayout);
          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(wrapper.emitted('save')).toBeUndefined();
        });
      });
    });

    describe('project', () => {
      beforeEach(async () => {
        factory({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
          },
          handler: mockCountResponse(1001),
        });

        await waitForPromises();
      });

      it('does not show the warning when performance threshold is reached but schedule rules were selected for a project', async () => {
        await selectScheduleRule();
        await waitForPromises();

        findPolicyEditorLayout().vm.$emit('save-policy');
        await waitForPromises();

        expect(findOverloadWarningModal().props('visible')).toBe(false);
        expect(wrapper.emitted('save')[0]).toHaveLength(1);
      });
    });
  });

  describe('skip ci configuration', () => {
    const skipCi = {
      allowed: false,
      allowlist: {
        users: [{ id: 1 }, { id: 2 }],
      },
    };

    it('renders skip ci configuration', () => {
      factory();

      expect(findSkipCiSelector().exists()).toBe(true);
      expect(findSkipCiSelector().props('skipCiConfiguration')).toEqual(
        DEFAULT_SKIP_SI_CONFIGURATION,
      );
    });

    it('renders existing skip ci configuration', () => {
      factoryWithExistingPolicy({
        policy: {
          skip_ci: skipCi,
        },
      });

      expect(findSkipCiSelector().props('skipCiConfiguration')).toEqual(skipCi);
    });

    it('renders existing default skip ci configuration when it is removed from yaml', async () => {
      factoryWithExistingPolicy({
        policy: {
          skip_ci: skipCi,
        },
      });

      expect(findSkipCiSelector().props('skipCiConfiguration')).toEqual(skipCi);
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockDastScanExecutionManifest);

      expect(findSkipCiSelector().findComponent(GlToggle).props('value')).toBe(
        !DEFAULT_SKIP_SI_CONFIGURATION.allowed,
      );
    });
  });

  describe('new yaml format with type as a wrapper', () => {
    beforeEach(() => {
      factory();
    });

    it('renders default yaml in new format', () => {
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
        DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_WITH_DEFAULT_VARIABLES,
      );
    });

    it('converts new policy format to old policy format when saved', async () => {
      findPolicyEditorLayout().vm.$emit('save-policy');
      await waitForPromises();

      expect(wrapper.emitted('save')).toEqual([
        [
          {
            action: undefined,
            policy: `name: ''
description: ''
enabled: true
policy_scope:
  projects:
    excluding: []
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
    variables:
      SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
skip_ci:
  allowed: true
type: scan_execution_policy
`,
          },
        ],
      ]);
    });
  });
});
