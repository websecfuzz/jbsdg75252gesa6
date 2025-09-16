import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import { EXCEPT_PROJECTS } from 'ee/security_orchestration/components/policy_editor/scope/constants';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import waitForPromises from 'helpers/wait_for_promises';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import { verify } from '../utils';
import {
  APPROVAL_POLICY,
  DEFAULT_PROVIDE,
  PIPELINE_EXECUTION_POLICY,
  SCAN_EXECUTION_POLICY,
} from '../mocks/mocks';
import {
  createMockApolloProvider,
  createSppLinkedItemsHandler,
  defaultHandlers,
} from './apollo_utils';
import {
  EXCLUDING_PROJECTS_MOCKS,
  EXCLUDING_PROJECTS_ON_PROJECT_LEVEL,
  EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS,
} from './mocks';

describe('Policy Scope With Exceptions', () => {
  let wrapper;

  const createWrapper = ({
    propsData = {},
    provide = {},
    glFeatures = {},
    handlers = defaultHandlers,
  } = {}) => {
    wrapper = mountExtended(App, {
      apolloProvider: createMockApolloProvider(handlers),
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        existingPolicy: null,
        ...DEFAULT_PROVIDE,
        glFeatures,
        ...provide,
      },
      stubs: {
        SourceEditor: true,
      },
    });
  };

  const findExceptionTypeSelector = () => wrapper.findByTestId('exception-type');
  const findGroupProjectsDropdown = () => wrapper.findComponent(GroupProjectsDropdown);
  const findProjectText = () => wrapper.findByTestId('policy-scope-project-text');

  const verifyRuleMode = () => {
    expect(findGroupProjectsDropdown().exists()).toBe(true);
  };

  const selectExceptionProjectsOption = async () => {
    await findExceptionTypeSelector().vm.$emit('select', EXCEPT_PROJECTS);
    await findGroupProjectsDropdown().vm.$emit('select', [
      { id: convertToGraphQLId(TYPENAME_PROJECT, 1) },
      { id: convertToGraphQLId(TYPENAME_PROJECT, 2) },
    ]);
  };

  describe('group level', () => {
    describe.each`
      policyType                   | manifest
      ${SCAN_EXECUTION_POLICY}     | ${EXCLUDING_PROJECTS_MOCKS.SCAN_EXECUTION}
      ${PIPELINE_EXECUTION_POLICY} | ${EXCLUDING_PROJECTS_ON_PROJECT_LEVEL}
      ${APPROVAL_POLICY}           | ${EXCLUDING_PROJECTS_MOCKS.APPROVAL_POLICY}
    `('$policyType', ({ policyType, manifest }) => {
      beforeEach(() => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(policyType);

        createWrapper({
          provide: {
            namespaceType: NAMESPACE_TYPES.GROUP,
          },
        });
      });

      it('selects project exceptions on group level', async () => {
        await selectExceptionProjectsOption();

        await verify({ manifest, verifyRuleMode, wrapper });
      });
    });
  });

  describe('project level', () => {
    describe.each`
      policyType                   | manifest
      ${SCAN_EXECUTION_POLICY}     | ${EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.SCAN_EXECUTION}
      ${PIPELINE_EXECUTION_POLICY} | ${EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.PIPELINE_EXECUTION}
      ${APPROVAL_POLICY}           | ${EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.APPROVAL_POLICY}
    `('$policyType', ({ policyType, manifest }) => {
      beforeEach(() => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(policyType);
      });

      it('renders project scope message', async () => {
        createWrapper();
        await waitForPromises();

        expect(findProjectText().exists()).toBe(true);
      });

      it('selects project exceptions on project level for SPP', async () => {
        createWrapper({
          handlers: {
            ...defaultHandlers,
            sppLinkedItemsHandler: createSppLinkedItemsHandler({
              projects: [
                { id: '1', name: 'name1', fullPath: 'fullPath1' },
                { id: '2', name: 'name2', fullPath: 'fullPath2' },
              ],
              namespaces: [
                { id: '1', name: 'name1', fullPath: 'fullPath1' },
                { id: '2', name: 'name2', fullPath: 'fullPath2' },
              ],
            }),
          },
        });

        await waitForPromises();
        await selectExceptionProjectsOption();

        await verify({ manifest, verifyRuleMode, wrapper });
      });
    });
  });
});
