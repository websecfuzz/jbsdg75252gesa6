import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ScopeProjectSelector from 'ee/security_orchestration/components/policy_editor/scope/scope_project_selector.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import { generateMockProjects } from 'ee_jest/security_orchestration/mocks/mock_data';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { EXCEPT_PROJECTS } from 'ee/security_orchestration/components/policy_editor/scope/constants';
import { WITHOUT_EXCEPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import InstanceProjectsDropdown from 'ee/security_orchestration/components/shared/instance_projects_dropdown.vue';

describe('ScopeProjectSelector', () => {
  let wrapper;

  const projects = generateMockProjects([1, 2]);
  const mappedProjects = projects.map(({ id }) => ({ id: getIdFromGraphQLId(id) }));

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ScopeProjectSelector, {
      propsData: {
        groupFullPath: 'gitlab-org',
        projects: { excluding: [] },
        ...propsData,
      },
      provide: { designatedAsCsp: false, ...provide },
    });
  };

  const findExceptionTypeSelector = () => wrapper.findByTestId('exception-type');
  const findGroupProjectsDropdown = () => wrapper.findComponent(GroupProjectsDropdown);
  const findInstanceProjectsDropdown = () => wrapper.findComponent(InstanceProjectsDropdown);

  describe('default rendering', () => {
    it('renders exceptions type selector', () => {
      createComponent();

      expect(findExceptionTypeSelector().exists()).toBe(true);
      expect(findGroupProjectsDropdown().exists()).toBe(false);
    });

    it('renders exceptions type selector with empty projects', () => {
      createComponent({
        propsData: { projects: {} },
      });

      expect(findExceptionTypeSelector().exists()).toBe(true);
      expect(findGroupProjectsDropdown().exists()).toBe(false);
    });
  });

  describe('renders projects selector', () => {
    describe('non-csp group', () => {
      it('renders group projects selector when exception type is selected', () => {
        createComponent({
          propsData: { exceptionType: EXCEPT_PROJECTS },
        });

        expect(findGroupProjectsDropdown().exists()).toBe(true);
        expect(findInstanceProjectsDropdown().exists()).toBe(false);
      });

      it('renders group projects selector when exceptions are disabled', () => {
        createComponent({
          propsData: {
            projects: {
              including: [],
            },
          },
        });

        expect(findExceptionTypeSelector().exists()).toBe(false);
        expect(findGroupProjectsDropdown().exists()).toBe(true);
        expect(findInstanceProjectsDropdown().exists()).toBe(false);
      });
    });

    describe('csp group', () => {
      it('renders instance projects selector when exception type is selected', () => {
        createComponent({
          propsData: { exceptionType: EXCEPT_PROJECTS },
          provide: { designatedAsCsp: true },
        });

        expect(findGroupProjectsDropdown().exists()).toBe(false);
        expect(findInstanceProjectsDropdown().exists()).toBe(true);
      });

      it('renders instance projects selector when exceptions are disabled', () => {
        createComponent({
          propsData: {
            projects: {
              including: [],
            },
          },
          provide: { designatedAsCsp: true },
        });

        expect(findExceptionTypeSelector().exists()).toBe(false);
        expect(findGroupProjectsDropdown().exists()).toBe(false);
        expect(findInstanceProjectsDropdown().exists()).toBe(true);
      });
    });
  });

  describe.each`
    title              | designatedAsCsp | findProjectSelector
    ${'non-csp group'} | ${false}        | ${findGroupProjectsDropdown}
    ${'csp group'}     | ${true}         | ${findInstanceProjectsDropdown}
  `('$title', ({ designatedAsCsp, findProjectSelector }) => {
    describe('project selection', () => {
      it('should select exception projects', () => {
        createComponent({
          propsData: { exceptionType: EXCEPT_PROJECTS },
          provide: { designatedAsCsp },
        });

        findProjectSelector().vm.$emit('select', projects);

        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              projects: {
                excluding: mappedProjects,
              },
            },
          ],
        ]);
      });

      it('should select specific projects', () => {
        createComponent({
          propsData: {
            projects: {
              including: [],
            },
          },
          provide: { designatedAsCsp },
        });

        findProjectSelector().vm.$emit('select', projects);

        expect(wrapper.emitted('changed')).toEqual([
          [
            {
              projects: {
                including: mappedProjects,
              },
            },
          ],
        ]);
      });
    });

    describe('error state', () => {
      it('emits error when projects loading fails', () => {
        createComponent({
          propsData: {
            projects: {
              including: mappedProjects,
            },
          },
          provide: { designatedAsCsp },
        });

        findProjectSelector().vm.$emit('projects-query-error');

        expect(wrapper.emitted('error')).toEqual([['Failed to load group projects']]);
      });

      it('does not render initial error state for a dropdown', () => {
        createComponent({
          propsData: {
            projects: {
              including: mappedProjects,
            },
          },
          provide: { designatedAsCsp },
        });
        expect(findProjectSelector().props('state')).toBe(true);
      });

      it('renders error state for a dropdown when form is dirty', () => {
        createComponent({
          propsData: {
            isDirty: true,
            projects: {
              including: [],
            },
          },
          provide: { designatedAsCsp },
        });
        expect(findProjectSelector().props('state')).toBe(false);
      });
    });
  });

  describe('selected projects', () => {
    describe('non-csp group', () => {
      it.each`
        key            | projectType    | hasExceptions
        ${'excluding'} | ${'exception'} | ${true}
        ${'including'} | ${'specific'}  | ${false}
      `('renders selected $projectType projects', ({ key, hasExceptions }) => {
        createComponent({
          propsData: {
            projects: {
              [key]: mappedProjects,
            },
            exceptionType: EXCEPT_PROJECTS,
          },
        });

        expect(findExceptionTypeSelector().exists()).toBe(hasExceptions);
        expect(findGroupProjectsDropdown().props('selected')).toEqual([
          projects[0].id,
          projects[1].id,
        ]);
      });
    });

    describe('csp group', () => {
      it.each`
        key            | projectType    | hasExceptions
        ${'excluding'} | ${'exception'} | ${true}
        ${'including'} | ${'specific'}  | ${false}
      `('renders selected $projectType projects', ({ key, hasExceptions }) => {
        createComponent({
          propsData: {
            projects: {
              [key]: mappedProjects,
            },
            exceptionType: EXCEPT_PROJECTS,
          },
          provide: { designatedAsCsp: true },
        });

        expect(findExceptionTypeSelector().exists()).toBe(hasExceptions);
        expect(findInstanceProjectsDropdown().props('selected')).toEqual([1, 2]);
      });
    });
  });

  describe('select exceptions', () => {
    it('selects exception type', () => {
      createComponent();

      findExceptionTypeSelector().vm.$emit('select', EXCEPT_PROJECTS);

      expect(wrapper.emitted('select-exception-type')).toEqual([[EXCEPT_PROJECTS]]);
    });
  });

  describe('reset selected projects', () => {
    it('should select exception type WITHOUT_EXCEPTIONS and reset exceptions', () => {
      createComponent({
        propsData: {
          projects: {
            excluding: mappedProjects,
          },
        },
      });

      findExceptionTypeSelector().vm.$emit('select', WITHOUT_EXCEPTIONS);

      expect(wrapper.emitted('select-exception-type')).toEqual([[WITHOUT_EXCEPTIONS]]);
      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            projects: {
              excluding: [],
            },
          },
        ],
      ]);
    });
  });
});
