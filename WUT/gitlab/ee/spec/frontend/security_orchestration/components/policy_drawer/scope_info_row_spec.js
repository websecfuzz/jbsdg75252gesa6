import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ScopeInfoRow from 'ee/security_orchestration/components/policy_drawer/scope_info_row.vue';
import ComplianceFrameworksToggleList from 'ee/security_orchestration/components/policy_drawer/compliance_frameworks_toggle_list.vue';
import LoaderWithMessage from 'ee/security_orchestration/components/loader_with_message.vue';
import ProjectsToggleList from 'ee/security_orchestration/components/policy_drawer/projects_toggle_list.vue';
import GroupsToggleList from 'ee/security_orchestration/components/policy_drawer/groups_toggle_list.vue';
import ScopeDefaultLabel from 'ee/security_orchestration/components/scope_default_label.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import { mockLinkedSppItemsResponse } from 'ee_jest/security_orchestration/mocks/mock_apollo';

describe('ScopeInfoRow', () => {
  let wrapper;
  let requestHandler;

  const items = [{ id: 1 }, { id: 2 }];

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[getSppLinkedProjectsGroups, requestHandler]]);
  };

  const createComponent = ({
    propsData = {},
    provide = {},
    handler = mockLinkedSppItemsResponse(),
  } = {}) => {
    wrapper = shallowMountExtended(ScopeInfoRow, {
      apolloProvider: createMockApolloProvider(handler),
      propsData,
      provide: {
        namespaceType: NAMESPACE_TYPES.GROUP,
        namespacePath: 'gitlab-org',
        ...provide,
      },
      stubs: {
        ScopeDefaultLabel,
      },
    });
  };

  const findComplianceFrameworksToggleList = () =>
    wrapper.findComponent(ComplianceFrameworksToggleList);
  const findGroupsToggleList = () => wrapper.findComponent(GroupsToggleList);
  const findProjectsToggleList = () => wrapper.findComponent(ProjectsToggleList);
  const findDefaultScopeLabel = () => wrapper.findComponent(ScopeDefaultLabel);
  const findPolicyScopeSection = () => wrapper.findByTestId('policy-scope');
  const findLoader = () => wrapper.findComponent(LoaderWithMessage);
  const findPolicyScopeProjectText = () => wrapper.findByTestId('default-project-text');

  describe('group level', () => {
    it(`renders policy scope for`, () => {
      createComponent();

      expect(findPolicyScopeSection().exists()).toBe(true);
      expect(findDefaultScopeLabel().exists()).toBe(true);
      expect(requestHandler).toHaveBeenCalledTimes(0);
    });

    it('renders policy scope for compliance frameworks', () => {
      createComponent({
        propsData: {
          policyScope: {
            complianceFrameworks: {
              nodes: [{ id: 1 }, { id: 2 }],
            },
          },
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(true);
      expect(findProjectsToggleList().exists()).toBe(false);
      expect(findComplianceFrameworksToggleList().props('complianceFrameworks')).toEqual([
        { id: 1 },
        { id: 2 },
      ]);
    });

    it.each`
      projectType
      ${'includingProjects'}
      ${'excludingProjects'}
    `('renders policy scope for projects with $projectType', ({ projectType }) => {
      createComponent({
        propsData: {
          policyScope: {
            [projectType]: {
              nodes: [{ id: 1 }, { id: 2 }],
            },
          },
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findProjectsToggleList().exists()).toBe(true);
      expect(findProjectsToggleList().props()).toEqual(
        expect.objectContaining({
          isGroup: true,
          isInstanceLevel: false,
          including: projectType === 'includingProjects',
          projects: [{ id: 1 }, { id: 2 }],
        }),
      );
    });

    it.each`
      policyScope                                                                                                    | namespaceType            | expectedText
      ${{}}                                                                                                          | ${NAMESPACE_TYPES.GROUP} | ${'Default mode'}
      ${undefined}                                                                                                   | ${NAMESPACE_TYPES.GROUP} | ${'Default mode'}
      ${null}                                                                                                        | ${NAMESPACE_TYPES.GROUP} | ${'Default mode'}
      ${{ complianceFrameworks: { nodes: [] } }}                                                                     | ${NAMESPACE_TYPES.GROUP} | ${'This policy is applied to current project.'}
      ${{ includingProjects: { nodes: [] } }}                                                                        | ${NAMESPACE_TYPES.GROUP} | ${'This policy is applied to current project.'}
      ${{ complianceFrameworks: { nodes: undefined } }}                                                              | ${NAMESPACE_TYPES.GROUP} | ${'This policy is applied to current project.'}
      ${{ includingProjects: { nodes: undefined } }}                                                                 | ${NAMESPACE_TYPES.GROUP} | ${'This policy is applied to current project.'}
      ${{ excludingProjects: { nodes: undefined } }}                                                                 | ${NAMESPACE_TYPES.GROUP} | ${'This policy is applied to current project.'}
      ${{ excludingProjects: { nodes: [] } }}                                                                        | ${NAMESPACE_TYPES.GROUP} | ${'This policy is applied to current project.'}
      ${{ complianceFrameworks: { nodes: null } }}                                                                   | ${NAMESPACE_TYPES.GROUP} | ${'This policy is applied to current project.'}
      ${{ includingProjects: { nodes: null } }}                                                                      | ${NAMESPACE_TYPES.GROUP} | ${'This policy is applied to current project.'}
      ${{ excludingProjects: { nodes: null } }}                                                                      | ${NAMESPACE_TYPES.GROUP} | ${'This policy is applied to current project.'}
      ${{ includingProjects: { nodes: [] }, excludingProjects: { nodes: [] }, complianceFrameworks: { nodes: [] } }} | ${NAMESPACE_TYPES.GROUP} | ${'Default mode'}
    `('renders for policyScope of $policyScope', ({ policyScope, namespaceType, expectedText }) => {
      createComponent({
        propsData: {
          policyScope,
        },
        provide: {
          namespaceType,
        },
      });

      expect(findDefaultScopeLabel().exists()).toBe(true);
      expect(findDefaultScopeLabel().text()).toBe(expectedText);
    });

    describe('group scope', () => {
      it('renders group scope when groups are provided', () => {
        createComponent({
          propsData: {
            policyScope: {
              includingGroups: {
                nodes: items,
              },
            },
          },
        });

        expect(findGroupsToggleList().exists()).toBe(true);
        expect(findGroupsToggleList().props('isLink')).toBe(true);
        expect(findGroupsToggleList().props('groups')).toEqual(items);
        expect(findGroupsToggleList().props('projects')).toEqual([]);
      });

      it('renders group scope when groups and project exceptions are provided', () => {
        createComponent({
          propsData: {
            policyScope: {
              includingGroups: {
                nodes: items,
              },
              excludingProjects: {
                nodes: items,
              },
            },
          },
        });

        expect(findGroupsToggleList().exists()).toBe(true);
        expect(findGroupsToggleList().props('groups')).toEqual(items);
        expect(findGroupsToggleList().props('projects')).toEqual(items);
      });

      it('does not render group scope when groups are empty and project exceptions are provided', () => {
        createComponent({
          propsData: {
            policyScope: {
              includingGroups: {
                nodes: [],
              },
              excludingProjects: {
                nodes: items,
              },
            },
          },
        });

        expect(findGroupsToggleList().exists()).toBe(false);
        expect(findProjectsToggleList().props('projects')).toEqual(items);
      });
    });
  });

  describe('project level', () => {
    it('should check linked items on project level', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(findLoader().exists()).toBe(true);
      expect(requestHandler).toHaveBeenCalledWith({
        fullPath: 'gitlab-org',
      });
    });

    it('should not check linked items on group level', async () => {
      createComponent();

      await waitForPromises();

      expect(findLoader().exists()).toBe(false);
      expect(requestHandler).toHaveBeenCalledTimes(0);
    });

    it('show text message for project without linked items', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      await waitForPromises();

      expect(findPolicyScopeProjectText().text()).toBe(
        'This policy is applied to current project.',
      );
    });

    it('does not render group scope when groups and project exceptions are provided on project level', () => {
      createComponent({
        propsData: {
          policyScope: {
            includingGroups: {
              nodes: items,
            },
            excludingProjects: {
              nodes: items,
            },
          },
        },
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(findGroupsToggleList().exists()).toBe(false);
    });

    it('renders group scope when groups and project exceptions are provided on project level', async () => {
      createComponent({
        handler: mockLinkedSppItemsResponse({
          projects: [
            { id: '1', name: 'name1', fullPath: 'fullPath1' },
            { id: '2', name: 'name2', fullPath: 'fullPath2' },
          ],
          groups: [
            { id: '1', name: 'name1', fullPath: 'fullPath1' },
            { id: '2', name: 'name2', fullPath: 'fullPath2' },
          ],
        }),
        propsData: {
          policyScope: {
            includingGroups: {
              nodes: items,
            },
            excludingProjects: {
              nodes: items,
            },
          },
        },
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      await waitForPromises();
      expect(findGroupsToggleList().exists()).toBe(true);
      expect(findGroupsToggleList().props('groups')).toEqual(items);
      expect(findGroupsToggleList().props('projects')).toEqual(items);
    });
  });
});
