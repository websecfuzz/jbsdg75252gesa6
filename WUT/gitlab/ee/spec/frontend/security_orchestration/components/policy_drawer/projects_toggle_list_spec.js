import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectsToggleList from 'ee/security_orchestration/components/policy_drawer/projects_toggle_list.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import ToggleList from 'ee/security_orchestration/components/policy_drawer/toggle_list.vue';

describe('ProjectsToggleList', () => {
  let wrapper;

  const defaultNodes = [
    {
      id: convertToGraphQLId(TYPENAME_PROJECT, 1),
      name: '1',
      fullPath: 'project-1-full-path',
      repository: { rootRef: 'main' },
    },
    {
      id: convertToGraphQLId(TYPENAME_PROJECT, 2),
      name: '2',
      fullPath: 'project-2-full-path',
      repository: { rootRef: 'main' },
    },
  ];

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectsToggleList, {
      propsData: {
        projects: defaultNodes,
        ...propsData,
      },
    });
  };

  const findToggleList = () => wrapper.findComponent(ToggleList);
  const findHeader = () => wrapper.findByTestId('toggle-list-header');

  describe('all projects', () => {
    describe('many projects', () => {
      beforeEach(() => {
        createComponent({
          propsData: {
            projects: [],
          },
        });
      });

      it('should not render toggle list', () => {
        expect(findToggleList().exists()).toBe(false);
      });

      it('should render header for all projects', () => {
        expect(findHeader().text()).toBe('All projects in this group');
      });
    });

    describe('single project', () => {
      it('renders header and list for all projects when there is single project in the group', () => {
        createComponent({
          propsData: {
            projects: [defaultNodes[0]],
          },
        });

        expect(findHeader().text()).toBe('All projects in this group except:');
        expect(findToggleList().props('items')).toHaveLength(1);
      });

      it('renders header and list for all projects when there is single project in the instance', () => {
        createComponent({
          propsData: {
            isInstanceLevel: true,
            projects: [defaultNodes[0]],
          },
        });

        expect(findHeader().text()).toBe('All projects in this instance except:');
        expect(findToggleList().props('items')).toHaveLength(1);
      });
    });
  });

  describe('specific projects', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          projects: [defaultNodes[0]],
          including: true,
        },
      });
    });

    it('should render toggle list with specific projects', () => {
      expect(findToggleList().exists()).toBe(true);
      expect(findToggleList().props('items')).toEqual(['1']);
    });

    it('should render header for specific projects', () => {
      expect(findHeader().text()).toBe('1 project:');
    });
  });

  describe('project level', () => {
    it('should render toggle list and specific header for all projects', () => {
      createComponent({
        propsData: {
          isGroup: false,
        },
      });

      expect(findToggleList().exists()).toBe(true);
      expect(findHeader().text()).toBe('All projects linked to this project except:');
    });

    it('should render toggle list and specific header for specific projects', () => {
      createComponent({
        propsData: {
          isGroup: false,
          including: true,
        },
      });

      expect(findToggleList().exists()).toBe(true);
      expect(findHeader().text()).toBe('2 projects:');
    });
  });

  describe('partial list', () => {
    it('renders partial lists for projects', () => {
      createComponent({
        propsData: {
          projectsToShow: 3,
          inlineList: true,
        },
      });

      expect(findToggleList().props('itemsToShow')).toBe(3);
      expect(findToggleList().props('inlineList')).toBe(true);
    });
  });
});
