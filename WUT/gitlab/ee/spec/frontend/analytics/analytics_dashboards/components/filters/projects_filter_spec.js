import VueApollo from 'vue-apollo';
import Vue from 'vue';
import GetDefaultProjectQuery from 'ee/analytics/analytics_dashboards/components/filters/get_default_project.query.graphql';
import ProjectsFilter from 'ee/analytics/analytics_dashboards/components/filters/projects_filter.vue';
import ProjectsDropdownFilter from '~/analytics/shared/components/projects_dropdown_filter.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';

Vue.use(VueApollo);

describe('ProjectsFilter', () => {
  let wrapper;
  let mockHandler;

  const mockDefaultProject = {
    id: 'abc',
    fullPath: 'project/path',
    name: 'test-project',
    avatarUrl: 'avatarUrl',
  };

  const createComponent = async (mockGetProjectHandler) => {
    mockHandler =
      mockGetProjectHandler ||
      jest.fn().mockResolvedValue({
        data: {
          project: { ...mockDefaultProject },
        },
      });

    const apolloProvider = createMockApollo([[GetDefaultProjectQuery, mockHandler]]);

    wrapper = shallowMountExtended(ProjectsFilter, {
      apolloProvider,
      propsData: {
        groupNamespace: 'group/subgroup',
      },
    });

    await waitForPromises();
  };

  const findProjectsDropdownFilter = () => wrapper.findComponent(ProjectsDropdownFilter);

  describe('default', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('renders ProjectsDropdownFilter component', () => {
      expect(findProjectsDropdownFilter().exists()).toBe(true);
    });

    it('passes correct props to ProjectsDropdownFilter', () => {
      const dropdownFilter = findProjectsDropdownFilter();

      expect(dropdownFilter.props()).toMatchObject({
        toggleClasses: 'gl-max-w-26',
        queryParams: {
          first: 50,
          includeSubgroups: true,
        },
        groupNamespace: 'group/subgroup',
      });
    });

    it('does not set default projects', () => {
      expect(findProjectsDropdownFilter().props('defaultProjects')).toEqual([]);
    });

    it('does not load the defaultProjects', () => {
      expect(findProjectsDropdownFilter().props('loadingDefaultProjects')).toBe(false);
      expect(mockHandler).not.toHaveBeenCalled();
    });
  });

  describe('when project query param is set', () => {
    beforeEach(() => {
      setWindowLocation('?project=abc');
    });
    describe('when loading is done', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('loads the default project', () => {
        expect(mockHandler).toHaveBeenCalledWith({ fullPath: 'abc' });
      });
      it('set the defaultProjects', () => {
        expect(findProjectsDropdownFilter().props('defaultProjects')).toEqual([mockDefaultProject]);
      });

      it('sets loadingDefaultProjects to false', () => {
        expect(findProjectsDropdownFilter().props('loadingDefaultProjects')).toBe(false);
      });
    });
    describe('while loading', () => {
      beforeEach(() => {
        createComponent();
      });
      it('sets loadingDefaultProjects to true', () => {
        expect(findProjectsDropdownFilter().props('loadingDefaultProjects')).toBe(true);
      });
    });
  });

  describe('onProjectsSelected', () => {
    beforeEach(async () => {
      await createComponent();
    });
    it('emits projectSelected event with correct values when a project is selected', () => {
      expect(wrapper.emitted('projectSelected')).toBeUndefined();

      const selectedProject = {
        fullPath: 'group/project',
        id: '123',
      };
      findProjectsDropdownFilter().vm.$emit('selected', [selectedProject]);

      expect(wrapper.emitted('projectSelected')).toEqual([[selectedProject]]);
    });

    it('emits projectSelected event with null payload when no project is selected (e.g. selection cleared)', () => {
      findProjectsDropdownFilter().vm.$emit('selected', []);

      expect(wrapper.emitted('projectSelected')).toEqual([[null]]);
    });
  });
});
