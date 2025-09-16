import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListComponentScope from 'ee/security_orchestration/components/policies/list_component_scope.vue';
import ComplianceFrameworksToggleList from 'ee/security_orchestration/components/policy_drawer/compliance_frameworks_toggle_list.vue';
import ProjectsToggleList from 'ee/security_orchestration/components/policy_drawer/projects_toggle_list.vue';
import GroupsToggleList from 'ee/security_orchestration/components/policy_drawer/groups_toggle_list.vue';
import ScopeDefaultLabel from 'ee/security_orchestration/components/scope_default_label.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('ListComponentScope', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ListComponentScope, {
      propsData,
      provide: {
        namespaceType: NAMESPACE_TYPES.GROUP,
        ...provide,
      },
    });
  };

  const findComplianceFrameworksToggleList = () =>
    wrapper.findComponent(ComplianceFrameworksToggleList);
  const findScopeDefaultLabel = () => wrapper.findComponent(ScopeDefaultLabel);
  const findGroupsToggleList = () => wrapper.findComponent(GroupsToggleList);
  const findProjectsToggleList = () => wrapper.findComponent(ProjectsToggleList);
  const findDefaultText = () => wrapper.findByTestId('default-text');

  describe('policy without policy scope', () => {
    it('renders default label', () => {
      createComponent();

      expect(findScopeDefaultLabel().exists()).toBe(true);
      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findProjectsToggleList().exists()).toBe(false);

      expect(findScopeDefaultLabel().props('policyScope')).toEqual(null);
      expect(findScopeDefaultLabel().props('isGroup')).toBe(true);
    });

    it('renders default text for empty policy scope on group level', () => {
      createComponent({
        propsData: {
          policyScope: {
            complianceFrameworks: { nodes: [] },
            includingProjects: { nodes: [] },
            excludingProjects: { nodes: [] },
          },
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findScopeDefaultLabel().exists()).toBe(true);
    });
  });

  describe('policy scope with compliance frameworks', () => {
    it('renders toggle list', () => {
      createComponent({
        propsData: {
          policyScope: {
            complianceFrameworks: { nodes: [{ id: 1 }] },
          },
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(true);
      expect(findScopeDefaultLabel().exists()).toBe(false);
      expect(findProjectsToggleList().exists()).toBe(false);

      expect(findComplianceFrameworksToggleList().props('complianceFrameworks')).toEqual([
        { id: 1 },
      ]);
    });
  });

  describe('excluding projects', () => {
    it('renders excluding project text for single project exception', () => {
      createComponent({
        propsData: {
          policyScope: {
            excludingProjects: { nodes: [{ id: 1 }] },
          },
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findScopeDefaultLabel().exists()).toBe(false);

      expect(findProjectsToggleList().exists()).toBe(true);
      expect(findProjectsToggleList().props()).toEqual(
        expect.objectContaining({
          including: false,
          projects: [{ id: 1 }],
        }),
      );
    });

    it('renders excluding project text for multiple project exception', () => {
      createComponent({
        propsData: {
          policyScope: {
            excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] },
          },
        },
      });

      expect(findProjectsToggleList().exists()).toBe(true);
      expect(findProjectsToggleList().props()).toEqual(
        expect.objectContaining({
          including: false,
          projects: [{ id: 1 }, { id: 2 }],
          projectsToShow: 2,
        }),
      );
    });

    it('renders instance-level policy', () => {
      createComponent({
        propsData: {
          isInstanceLevel: true,
          policyScope: {
            excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] },
          },
        },
      });
      expect(findProjectsToggleList().exists()).toBe(true);
      expect(findProjectsToggleList().props()).toEqual(
        expect.objectContaining({ isInstanceLevel: true }),
      );
    });
  });

  describe('including projects', () => {
    it('renders including project text for single specific project', () => {
      createComponent({
        propsData: {
          policyScope: {
            includingProjects: { nodes: [{ id: 1 }] },
          },
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findScopeDefaultLabel().exists()).toBe(false);

      expect(findProjectsToggleList().exists()).toBe(true);
      expect(findProjectsToggleList().props('including')).toBe(true);
      expect(findProjectsToggleList().props('projects')).toEqual([{ id: 1 }]);
    });

    it('renders including project text for multiple specific project', () => {
      createComponent({
        propsData: {
          policyScope: {
            includingProjects: { nodes: [{ id: 1 }, { id: 2 }, { id: 3 }] },
          },
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findScopeDefaultLabel().exists()).toBe(false);

      expect(findProjectsToggleList().exists()).toBe(true);
      expect(findProjectsToggleList().props()).toEqual(
        expect.objectContaining({
          including: true,
          projects: [{ id: 1 }, { id: 2 }, { id: 3 }],
        }),
      );
    });
  });

  describe('invalid policy scope values', () => {
    it.each`
      invalidProperty
      ${{ complianceFrameworks: [] }}
      ${{ including: [] }}
      ${{ excluding: [] }}
      ${{ complianceFrameworks: undefined }}
      ${{ projects: { including: undefined } }}
      ${{ projects: { excluding: undefined } }}
      ${{ compliance_frameworks: undefined }}
      ${{ projects: { including: null } }}
      ${{ projects: { excluding: null } }}
      ${{ compliance_frameworks: null }}
      ${{ projects: { including: [] } }}
      ${{ projects: { excluding: [] } }}
      ${{ compliance_frameworks: [] }}
    `('renders default label for invalid policy scope properties', ({ invalidProperty }) => {
      createComponent({
        propsData: {
          policyScope: {
            ...invalidProperty,
          },
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findProjectsToggleList().exists()).toBe(false);

      expect(findScopeDefaultLabel().exists()).toBe(false);
      expect(findDefaultText().exists()).toBe(true);
    });
  });

  describe('group scope', () => {
    const items = [{ id: 1 }, { id: 2 }];

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
      expect(findGroupsToggleList().props('groups')).toEqual(items);
      expect(findGroupsToggleList().props('projects')).toEqual([]);
      expect(findGroupsToggleList().props('inlineList')).toBe(true);
      expect(findGroupsToggleList().props('isLink')).toBe(false);
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

  describe('project level', () => {
    it('renders default text for empty policy scope on project level', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        propsData: {
          policyScope: {
            complianceFrameworks: { nodes: [] },
            includingProjects: { nodes: [] },
            excludingProjects: { nodes: [] },
          },
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findProjectsToggleList().exists()).toBe(false);
      expect(findScopeDefaultLabel().exists()).toBe(false);
      expect(findDefaultText().exists()).toBe(true);
    });

    it('renders default text for a policy with one linked SPP item on project level', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        propsData: {
          policyScope: {
            complianceFrameworks: { nodes: [] },
            includingProjects: { nodes: [] },
            excludingProjects: { nodes: [] },
          },
          linkedSppItems: [{ name: 'test' }],
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findProjectsToggleList().exists()).toBe(false);
      expect(findScopeDefaultLabel().exists()).toBe(false);
      expect(findDefaultText().exists()).toBe(true);
    });

    it('renders scope label for a policy with multiple linked SPP items on project level', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        propsData: {
          policyScope: {
            complianceFrameworks: { nodes: [] },
            includingProjects: { nodes: [] },
            excludingProjects: { nodes: [] },
          },
          linkedSppItems: [{ name: 'test' }, { name: 'test1' }],
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findProjectsToggleList().exists()).toBe(false);
      expect(findScopeDefaultLabel().exists()).toBe(true);
      expect(findScopeDefaultLabel().props('linkedItems')).toEqual([
        { name: 'test' },
        { name: 'test1' },
      ]);
      expect(findDefaultText().exists()).toBe(false);
    });

    it('renders compliance list for a policy with multiple linked SPP items on project level', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        propsData: {
          policyScope: {
            complianceFrameworks: { nodes: [{ id: 1 }] },
            includingProjects: { nodes: [] },
            excludingProjects: { nodes: [] },
          },
          linkedSppItems: [{ name: 'test' }, { name: 'test1' }],
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(true);
      expect(findComplianceFrameworksToggleList().props('complianceFrameworks')).toEqual([
        { id: 1 },
      ]);
      expect(findProjectsToggleList().exists()).toBe(false);
      expect(findScopeDefaultLabel().exists()).toBe(false);
      expect(findDefaultText().exists()).toBe(false);
    });

    it('renders project list for a policy with multiple linked SPP items and including projects and on project level', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        propsData: {
          policyScope: {
            complianceFrameworks: { nodes: [] },
            includingProjects: { nodes: [{ id: 1 }] },
            excludingProjects: { nodes: [] },
          },
          linkedSppItems: [{ name: 'test' }, { name: 'test1' }],
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findScopeDefaultLabel().exists()).toBe(false);
      expect(findDefaultText().exists()).toBe(false);

      expect(findProjectsToggleList().exists()).toBe(true);
      expect(findProjectsToggleList().props()).toEqual(
        expect.objectContaining({
          projects: [{ id: 1 }],
          including: true,
          isInstanceLevel: false,
        }),
      );
    });

    it('renders project list for a policy with multiple linked SPP and excluding projects item on project level', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        propsData: {
          policyScope: {
            complianceFrameworks: { nodes: [] },
            includingProjects: { nodes: [] },
            excludingProjects: { nodes: [{ id: 1 }] },
          },
          linkedSppItems: [{ name: 'test' }, { name: 'test1' }],
        },
      });

      expect(findComplianceFrameworksToggleList().exists()).toBe(false);
      expect(findScopeDefaultLabel().exists()).toBe(false);
      expect(findDefaultText().exists()).toBe(false);

      expect(findProjectsToggleList().exists()).toBe(true);
      expect(findProjectsToggleList().props()).toEqual(
        expect.objectContaining({
          projects: [{ id: 1 }],
          including: false,
        }),
      );
    });

    it('renders group policy scope when ff is enabled', () => {
      const items = [{ id: 1 }, { id: 2 }];

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
          linkedSppItems: [{ name: 'test' }, { name: 'test1' }],
        },
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(findGroupsToggleList().exists()).toBe(true);
      expect(findGroupsToggleList().props('groups')).toEqual(items);
      expect(findGroupsToggleList().props('projects')).toEqual(items);
    });
  });
});
