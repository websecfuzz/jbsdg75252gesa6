import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlSprintf, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import waitForPromises from 'helpers/wait_for_promises';
import ScopeSection from 'ee/security_orchestration/components/policy_editor/scope/scope_section.vue';
import ComplianceFrameworkDropdown from 'ee/security_orchestration/components/policy_editor/scope/compliance_framework_dropdown.vue';
import ScopeGroupSelector from 'ee/security_orchestration/components/policy_editor/scope/scope_group_selector.vue';
import ScopeProjectSelector from 'ee/security_orchestration/components/policy_editor/scope/scope_project_selector.vue';
import LoaderWithMessage from 'ee/security_orchestration/components/loader_with_message.vue';
import ScopeSectionAlert from 'ee/security_orchestration/components/policy_editor/scope/scope_section_alert.vue';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  ALL_PROJECTS_IN_GROUP,
  CSP_SCOPE_TYPE_LISTBOX_ITEMS,
  PROJECTS_WITH_FRAMEWORK,
  SPECIFIC_PROJECTS,
  EXCEPT_PROJECTS,
  WITHOUT_EXCEPTIONS,
  PROJECT_SCOPE_TYPE_LISTBOX_ITEMS,
  ALL_PROJECTS_IN_LINKED_GROUPS,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import {
  mockLinkedSppItemsResponse,
  defaultPageInfo,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';

describe('PolicyScope', () => {
  let wrapper;
  let requestHandler;

  const defaultAssignedPolicyProject = { fullPath: 'path/to/policy-project', branch: 'main' };
  const createHandler = ({ projects = [], namespaces = [] } = {}) =>
    jest.fn().mockResolvedValue({
      data: {
        project: {
          id: '1',
          securityPolicyProjectLinkedProjects: {
            nodes: projects,
            pageInfo: { ...defaultPageInfo },
          },
          securityPolicyProjectLinkedGroups: {
            nodes: namespaces,
            pageInfo: { ...defaultPageInfo },
          },
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[getSppLinkedProjectsGroups, requestHandler]]);
  };

  const createComponent = ({
    propsData,
    provide = {},
    handler = mockLinkedSppItemsResponse(),
  } = {}) => {
    wrapper = shallowMountExtended(ScopeSection, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        policyScope: {},
        ...propsData,
      },
      provide: {
        assignedPolicyProject: defaultAssignedPolicyProject,
        designatedAsCsp: false,
        existingPolicy: null,
        namespacePath: 'gitlab-org',
        namespaceType: NAMESPACE_TYPES.GROUP,
        rootNamespacePath: 'gitlab-org-root',
        ...provide,
      },
      stubs: {
        GlSprintf,
        ScopeSectionAlert,
        LoaderWithMessage,
      },
    });
  };

  const findGlAlert = () => wrapper.findComponent(GlAlert);
  const findComplianceFrameworkDropdown = () => wrapper.findComponent(ComplianceFrameworkDropdown);
  const findScopeProjectSelector = () => wrapper.findComponent(ScopeProjectSelector);
  const findScopeGroupSelector = () => wrapper.findComponent(ScopeGroupSelector);
  const findProjectScopeTypeDropdown = () => wrapper.findByTestId('project-scope-type');
  const findPolicyScopeProjectText = () => wrapper.findByTestId('policy-scope-project-text');
  const findLoader = () => wrapper.findComponent(LoaderWithMessage);
  const findScopeSectionAlert = () => wrapper.findComponent(ScopeSectionAlert);
  const findLoadingText = () => wrapper.findByTestId('loading-text');
  const findErrorMessage = () => wrapper.findByTestId('policy-scope-project-error');
  const findErrorMessageText = () => wrapper.findByTestId('policy-scope-project-error-text');
  const findDefaultScopeSelector = () => wrapper.findByTestId('default-scope-selector');
  const findIcon = () => wrapper.findComponent(GlIcon);

  beforeEach(() => {
    createComponent();
  });

  it('should render framework dropdown in initial state', () => {
    expect(findProjectScopeTypeDropdown().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
    expect(findProjectScopeTypeDropdown().props('disabled')).toBe(false);
    expect(findScopeProjectSelector().exists()).toBe(true);
    expect(findScopeProjectSelector().props('exceptionType')).toBe(WITHOUT_EXCEPTIONS);

    expect(findComplianceFrameworkDropdown().exists()).toBe(false);
    expect(findGlAlert().exists()).toBe(false);
  });

  it('should not check linked items on group level', async () => {
    await waitForPromises();

    expect(findLoader().exists()).toBe(false);
    expect(findProjectScopeTypeDropdown().exists()).toBe(true);
    expect(requestHandler).toHaveBeenCalledTimes(0);
    expect(findPolicyScopeProjectText().exists()).toBe(false);
  });

  it('should change scope and reset it', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);

    expect(findComplianceFrameworkDropdown().exists()).toBe(true);

    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          compliance_frameworks: [],
        },
      ],
    ]);

    await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

    expect(findScopeProjectSelector().exists()).toBe(true);
    expect(wrapper.text()).toBe('Apply this policy to');
    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          compliance_frameworks: [],
        },
      ],
      [
        {
          projects: {
            including: [],
          },
        },
      ],
    ]);
  });

  it('should select excluding projects', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_GROUP);

    expect(findScopeProjectSelector().exists()).toBe(true);

    await findScopeProjectSelector().vm.$emit('select-exception-type', EXCEPT_PROJECTS);

    findScopeProjectSelector().vm.$emit('changed', {
      projects: {
        excluding: [{ id: 1 }, { id: 2 }],
      },
    });

    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          projects: {
            excluding: [],
          },
        },
      ],
      [{ projects: { excluding: [{ id: 1 }, { id: 2 }] } }],
    ]);
  });

  it('should select including projects', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

    findScopeProjectSelector().vm.$emit('changed', {
      projects: {
        including: [{ id: 1 }, { id: 2 }],
      },
    });

    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          projects: {
            including: [],
          },
        },
      ],
      [{ projects: { including: [{ id: 1 }, { id: 2 }] } }],
    ]);
  });

  it('should select compliance frameworks', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);
    findComplianceFrameworkDropdown().vm.$emit('select', ['id1', 'id2']);

    expect(wrapper.emitted('changed')).toEqual([
      [{ compliance_frameworks: [] }],
      [{ compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }] }],
    ]);
  });

  describe('existing policy scope', () => {
    it('should render existing compliance frameworks', () => {
      createComponent({
        propsData: {
          policyScope: {
            compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }],
          },
        },
      });

      expect(findComplianceFrameworkDropdown().exists()).toBe(true);
      expect(findComplianceFrameworkDropdown().props('disabled')).toBe(false);
      expect(findComplianceFrameworkDropdown().props('selectedFrameworkIds')).toEqual([
        'id1',
        'id2',
      ]);

      expect(wrapper.text()).toBe('Apply this policy to named');
    });

    it('should render existing excluding projects', () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              excluding: [{ id: 'id1' }, { id: 'id2' }],
            },
          },
        },
      });

      expect(findComplianceFrameworkDropdown().exists()).toBe(false);

      expect(findScopeProjectSelector().props('exceptionType')).toBe(EXCEPT_PROJECTS);
      expect(findScopeProjectSelector().exists()).toBe(true);
      expect(findScopeProjectSelector().props('projects')).toEqual({
        excluding: [{ id: 'id1' }, { id: 'id2' }],
      });
    });

    it('should render existing including projects', () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              including: [{ id: 'id1' }, { id: 'id2' }],
            },
          },
        },
      });

      expect(findComplianceFrameworkDropdown().exists()).toBe(false);
      expect(findScopeProjectSelector().exists()).toBe(true);
      expect(wrapper.text()).toBe('Apply this policy to');
      expect(findScopeProjectSelector().props('projects')).toEqual({
        including: [{ id: 'id1' }, { id: 'id2' }],
      });
    });

    it('should render alert message for projects dropdown', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              including: [{ id: 'id1' }, { id: 'id2' }],
            },
          },
        },
      });

      await findScopeProjectSelector().vm.$emit('error');
      expect(findGlAlert().exists()).toBe(true);
    });

    it('should render alert message for compliance framework dropdown', async () => {
      await findProjectScopeTypeDropdown().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);

      await findComplianceFrameworkDropdown().vm.$emit('framework-query-error');
      expect(findGlAlert().exists()).toBe(true);
    });
  });

  describe('project level', () => {
    describe('security policy project', () => {
      const createComponentForSPP = async ({ provide = {} } = {}) => {
        createComponent({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
            ...provide,
          },
          handler: createHandler({
            projects: [
              { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
              { id: '2', name: 'name2', fullPath: 'fullPath2', descendantGroups: { nodes: [] } },
            ],
            groups: [
              { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
              { id: '2', name: 'name2', fullPath: 'fullPath2', descendantGroups: { nodes: [] } },
            ],
          }),
        });

        await waitForPromises();
      };

      describe('new policy', () => {
        beforeEach(async () => {
          await createComponentForSPP();
        });

        it('does not show the default scope option', () => {
          expect(findDefaultScopeSelector().exists()).toBe(false);
        });

        it('shows the enabled policy scope selector', () => {
          expect(findPolicyScopeProjectText().exists()).toBe(false);
          expect(findProjectScopeTypeDropdown().props('disabled')).toBe(false);
          expect(findScopeProjectSelector().exists()).toBe(true);
        });
      });

      describe('project level with policy group scope', () => {
        it('renders group selector when SPP has linked items', async () => {
          await createComponentForSPP();

          await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_LINKED_GROUPS);
          expect(findScopeGroupSelector().exists()).toBe(true);
          expect(findScopeGroupSelector().props('fullPath')).toBe('gitlab-org');
        });

        it('selects policy group scope on project level for SPP', async () => {
          await createComponentForSPP();

          await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_LINKED_GROUPS);
          await findScopeGroupSelector().vm.$emit('changed', {
            groups: {
              including: [{ id: 1 }, { id: 2 }],
            },
          });

          expect(wrapper.emitted('changed')).toEqual([
            [{ projects: { excluding: [] } }],
            [{ groups: { including: [] } }],
            [{ groups: { including: [{ id: 1 }, { id: 2 }] } }],
          ]);
        });

        it('does not render group selector when SPP has no linked items', async () => {
          createComponent({
            provide: {
              namespaceType: NAMESPACE_TYPES.PROJECT,
            },
          });

          await waitForPromises();

          expect(findProjectScopeTypeDropdown().exists()).toBe(false);
          expect(findPolicyScopeProjectText().text()).toBe('Apply this policy to current project.');
        });
      });

      describe('existing policy', () => {
        describe('no existing policy scope', () => {
          beforeEach(async () => {
            await createComponentForSPP({ provide: { existingPolicy: { name: 'A' } } });
          });

          it('displays the default scope and checks it', () => {
            expect(findDefaultScopeSelector().exists()).toBe(true);
            expect(findDefaultScopeSelector().attributes('checked')).toBe('true');
          });

          it('disables the scope dropdowns when default scope is set', () => {
            expect(findProjectScopeTypeDropdown().exists()).toBe(true);
            expect(findProjectScopeTypeDropdown().props('disabled')).toBe(true);
            expect(findScopeProjectSelector().props('disabled')).toBe(true);
          });

          it('enables the scope dropdowns when default scope is unchecked', async () => {
            await findDefaultScopeSelector().vm.$emit('input', false);
            expect(findProjectScopeTypeDropdown().props('disabled')).toBe(false);
            expect(findScopeProjectSelector().props('disabled')).toBe(false);
          });

          it('adds the policy scope yaml when default scope is unchecked', async () => {
            expect(wrapper.emitted('changed')).toEqual(undefined);
            await findDefaultScopeSelector().vm.$emit('change');
            expect(wrapper.emitted('changed')).toEqual([[{ projects: { excluding: [] } }]]);
          });

          it('does not emit default policy scope on load', () => {
            expect(wrapper.emitted('changed')).toEqual(undefined);
          });

          it('resets the selectors when default scope is checked', async () => {
            await findDefaultScopeSelector().vm.$emit('change');
            await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);
            expect(findProjectScopeTypeDropdown().props('selected')).toBe(SPECIFIC_PROJECTS);

            await findDefaultScopeSelector().vm.$emit('change', true);
            expect(findProjectScopeTypeDropdown().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
            expect(findScopeProjectSelector().exists()).toBe(true);
          });
        });
      });
    });

    it('should check linked items on project level', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(requestHandler).toHaveBeenCalledWith({
        fullPath: 'gitlab-org',
      });
    });

    it('show text message for project without linked items', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      await waitForPromises();

      expect(findPolicyScopeProjectText().text()).toBe('Apply this policy to current project.');
    });

    it('show compliance framework selector for projects with links', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        handler: mockLinkedSppItemsResponse({
          projects: [
            { id: '1', name: 'name1', fullPath: 'fullPath1' },
            { id: '2', name: 'name2', fullPath: 'fullPath2' },
          ],
          groups: [
            { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
            { id: '2', name: 'name2', fullPath: 'fullPath2', descendantGroups: { nodes: [] } },
          ],
        }),
      });

      await waitForPromises();

      expect(findPolicyScopeProjectText().exists()).toBe(false);
      expect(findProjectScopeTypeDropdown().exists()).toBe(true);
      expect(findScopeProjectSelector().props('exceptionType')).toBe(WITHOUT_EXCEPTIONS);
    });

    it('shows loading state', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(findLoader().exists()).toBe(true);
      expect(findLoadingText().text()).toBe('Fetching the scope information.');
    });

    it('shows error message when spp query fails', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        handler: jest.fn().mockRejectedValue({}),
      });

      await waitForPromises();

      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessageText().text()).toBe(
        'Failed to fetch the scope information. Please refresh the page to try again.',
      );
      expect(findIcon().props('name')).toBe('status_warning');
    });

    it('emits default policy scope on project level for SPP with multiple dependencies', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        handler: mockLinkedSppItemsResponse({
          projects: [
            { id: '1', name: 'name1', fullPath: 'fullPath1' },
            { id: '2', name: 'name2', fullPath: 'fullPath2' },
          ],
          groups: [
            { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
            { id: '2', name: 'name2', fullPath: 'fullPath2', descendantGroups: { nodes: [] } },
          ],
        }),
      });

      await waitForPromises();

      expect(wrapper.emitted('changed')).toEqual([[{ projects: { excluding: [] } }]]);
    });

    it('does not emit default policy scope on group level', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
        },
      });

      await waitForPromises();

      expect(wrapper.emitted('changed')).toBeUndefined();
    });
  });

  describe('namespace', () => {
    it.each`
      namespaceType              | expectedResult
      ${NAMESPACE_TYPES.GROUP}   | ${'gitlab-org-root'}
      ${NAMESPACE_TYPES.PROJECT} | ${'gitlab-org-root'}
    `('queries different namespaces on $namespaceType level', async ({ namespaceType }) => {
      createComponent({
        provide: {
          namespaceType,
        },
        handler: mockLinkedSppItemsResponse({
          projects: [
            { id: '1', name: 'name1', fullPath: 'fullPath1' },
            { id: '2', name: 'name2', fullPath: 'fullPath2' },
          ],
          groups: [
            { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
            { id: '2', name: 'name2', fullPath: 'fullPath2', descendantGroups: { nodes: [] } },
          ],
        }),
      });

      await waitForPromises();
      await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

      expect(findScopeProjectSelector().exists()).toBe(true);
    });
  });

  describe('error message and validation', () => {
    const findScopeAlert = () => findScopeSectionAlert().findComponent(GlAlert);

    it('should show alert when compliance frameworks are empty', async () => {
      createComponent({
        propsData: {
          policyScope: {
            compliance_frameworks: [],
          },
        },
      });

      expect(findScopeAlert().exists()).toBe(false);
      expect(findComplianceFrameworkDropdown().props('showError')).toBe(false);

      await findComplianceFrameworkDropdown().vm.$emit('select', ['id1']);

      expect(findScopeAlert().exists()).toBe(true);
      expect(findComplianceFrameworkDropdown().props('showError')).toBe(true);
    });

    it('should show alert when specific projects are empty', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              including: [],
            },
          },
        },
      });

      expect(findScopeAlert().exists()).toBe(false);

      await findScopeProjectSelector().vm.$emit('changed', { excluding: ['id1'] });

      expect(findScopeAlert().exists()).toBe(true);
      expect(findScopeSectionAlert().props()).toEqual({
        complianceFrameworksEmpty: true,
        isDirty: true,
        isProjectsWithoutExceptions: true,
        projectEmpty: true,
        groupsEmpty: true,
        projectScopeType: SPECIFIC_PROJECTS,
      });
    });

    it('should show alert when excluding projects are empty', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              excluding: [],
            },
          },
        },
      });

      expect(findScopeAlert().exists()).toBe(false);

      await findScopeProjectSelector().vm.$emit('select-exception-type', EXCEPT_PROJECTS);
      await findScopeProjectSelector().vm.$emit('changed', { excluding: ['id1'] });

      expect(findScopeAlert().exists()).toBe(true);

      expect(findScopeSectionAlert().props()).toEqual({
        complianceFrameworksEmpty: true,
        isDirty: true,
        isProjectsWithoutExceptions: false,
        projectEmpty: true,
        groupsEmpty: true,
        projectScopeType: ALL_PROJECTS_IN_GROUP,
      });
    });
  });

  describe('policy group scope', () => {
    describe('initial selection', () => {
      beforeEach(() => {
        createComponent();
      });

      it('has group scope type in scope dropdown', () => {
        expect(findProjectScopeTypeDropdown().props('items')).toEqual(
          PROJECT_SCOPE_TYPE_LISTBOX_ITEMS,
        );
      });

      it('should select including groups', async () => {
        await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_LINKED_GROUPS);

        expect(findScopeProjectSelector().exists()).toBe(false);
        expect(findScopeGroupSelector().exists()).toBe(true);

        findScopeGroupSelector().vm.$emit('changed', {
          groups: {
            including: [{ id: 1 }, { id: 2 }],
          },
        });

        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              groups: {
                including: [],
              },
            },
          ],
          [{ groups: { including: [{ id: 1 }, { id: 2 }] } }],
        ]);
      });

      it('should select including groups and project exceptions', async () => {
        await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_LINKED_GROUPS);

        expect(findScopeProjectSelector().exists()).toBe(false);
        expect(findScopeGroupSelector().exists()).toBe(true);

        findScopeGroupSelector().vm.$emit('changed', {
          groups: {
            including: [{ id: 1 }, { id: 2 }],
          },
          projects: {
            excluding: [{ id: 1 }, { id: 2 }],
          },
        });

        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              groups: {
                including: [],
              },
            },
          ],
          [
            {
              groups: { including: [{ id: 1 }, { id: 2 }] },
              projects: { excluding: [{ id: 1 }, { id: 2 }] },
            },
          ],
        ]);
      });
    });

    describe('selected groups', () => {
      it('renders existing policy group scope', () => {
        createComponent({
          propsData: {
            policyScope: {
              groups: {
                including: [],
              },
            },
          },
        });

        expect(findScopeGroupSelector().exists()).toBe(true);
        expect(findScopeProjectSelector().exists()).toBe(false);
      });

      it('renders existing policy group scope with selected groups', () => {
        createComponent({
          propsData: {
            policyScope: {
              groups: {
                including: [{ id: 1 }, { id: 2 }],
              },
            },
          },
        });

        expect(findScopeGroupSelector().exists()).toBe(true);
        expect(findScopeGroupSelector().props('groups')).toEqual({
          including: [{ id: 1 }, { id: 2 }],
        });
        expect(findScopeGroupSelector().props('exceptionType')).toBe(WITHOUT_EXCEPTIONS);
        expect(findScopeProjectSelector().exists()).toBe(false);
      });

      it('renders existing policy group scope with selected groups and projects', () => {
        createComponent({
          propsData: {
            policyScope: {
              groups: {
                including: [{ id: 1 }, { id: 2 }],
              },
              projects: {
                excluding: [{ id: 1 }, { id: 2 }],
              },
            },
          },
        });

        expect(findScopeGroupSelector().exists()).toBe(true);
        expect(findScopeGroupSelector().props('groups')).toEqual({
          including: [{ id: 1 }, { id: 2 }],
        });
        expect(findScopeGroupSelector().props('projects')).toEqual({
          excluding: [{ id: 1 }, { id: 2 }],
        });
        expect(findScopeGroupSelector().props('exceptionType')).toBe(EXCEPT_PROJECTS);
        expect(findScopeProjectSelector().exists()).toBe(false);
      });

      it('renders group scope selector even with including projects property', () => {
        createComponent({
          propsData: {
            policyScope: {
              groups: {
                including: [{ id: 1 }, { id: 2 }],
              },
              projects: {
                including: [{ id: 1 }, { id: 2 }],
              },
            },
          },
        });

        expect(findScopeGroupSelector().exists()).toBe(true);
        expect(findScopeProjectSelector().exists()).toBe(false);
      });
    });
  });

  describe('global compliance security policies group', () => {
    describe('scope type selection', () => {
      beforeEach(() => {
        createComponent({ provide: { designatedAsCsp: true } });
      });

      it('renders CSP scope dropdown items', () => {
        expect(findProjectScopeTypeDropdown().props('items')).toEqual(CSP_SCOPE_TYPE_LISTBOX_ITEMS);
      });

      it('displays CSP scope text as toggle text', () => {
        expect(findProjectScopeTypeDropdown().props('toggleText')).toBe(
          'all projects in this instance',
        );
      });

      it('renders ALL_PROJECTS_IN_GROUP as default selected value', () => {
        expect(findProjectScopeTypeDropdown().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
      });

      it('displays exception dropdown by default', () => {
        expect(findScopeProjectSelector().exists()).toBe(true);
      });
    });

    describe('scope selection behavior', () => {
      it('renders exception dropdown when CSP instance scope is selected', () => {
        createComponent({ provide: { designatedAsCsp: true } });

        findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_GROUP);

        expect(findScopeProjectSelector().exists()).toBe(true);
      });

      it('updates toggle text when scope changes in CSP context', async () => {
        createComponent({ provide: { designatedAsCsp: true } });

        findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);
        await nextTick();

        expect(findProjectScopeTypeDropdown().props('toggleText')).toBe('specific projects');
      });
    });
  });
});
