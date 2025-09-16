import { nextTick } from 'vue';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import GroupSecurityDashboardV2 from 'ee/security_dashboard/components/shared/security_dashboard_new.vue';
import ProjectToken from 'ee/security_dashboard/components/shared/filtered_search_v2/tokens/project_token.vue';
import VulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_panel.vue';

jest.mock('~/alert');

describe('Security Dashboard (new version) - Component', () => {
  let wrapper;

  const mockGroupFullPath = 'group/subgroup';

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(GroupSecurityDashboardV2, {
      propsData: {
        ...props,
      },
      provide: {
        groupFullPath: mockGroupFullPath,
      },
    });
  };

  const findDashboardLayout = () => wrapper.findComponent(DashboardLayout);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
  const getDashboardConfig = () => findDashboardLayout().props('config');
  const getFirstPanel = () => getDashboardConfig().panels[0];

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the dashboard layout component', () => {
      expect(findDashboardLayout().exists()).toBe(true);
    });

    it('passes the correct dashboard configuration to the layout', () => {
      const dashboardConfig = getDashboardConfig();

      expect(dashboardConfig.title).toBe('Security dashboard');
      expect(dashboardConfig.description).toBe(
        'This dashboard provides an overview of your security vulnerabilities.',
      );
    });

    it('renders the panels with the correct configuration', () => {
      const firstPanel = getFirstPanel();

      expect(firstPanel.component).toBe(VulnerabilitiesOverTimePanel);
      expect(firstPanel.gridAttributes).toEqual({
        width: 6,
        height: 4,
        yPos: 0,
        xPos: 0,
      });
    });
  });

  describe('filtered search', () => {
    it('gets passed the correct tokens', () => {
      expect(findFilteredSearch().props('tokens')).toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            type: 'projectId',
            title: 'Project',
            multiSelect: true,
            unique: true,
            token: markRaw(ProjectToken),
            operators: OPERATORS_OR,
          }),
        ]),
      );
    });

    it('updates filters when filters-changed event is emitted', async () => {
      const newFilters = { projectId: 'gid://gitlab/Project/123' };
      findFilteredSearch().vm.$emit('filters-changed', newFilters);
      await nextTick();

      expect(getFirstPanel().componentProps.filters).toEqual(newFilters);
    });

    it('clears filters when empty filters object is emitted', async () => {
      const initialFilters = { projectId: 'gid://gitlab/Project/123' };
      findFilteredSearch().vm.$emit('filters-changed', initialFilters);
      await nextTick();

      expect(getFirstPanel().componentProps.filters).toEqual(initialFilters);

      // Clear filters
      findFilteredSearch().vm.$emit('filters-changed', {});
      await nextTick();

      expect(getFirstPanel().componentProps.filters).toEqual({});
    });

    it('passes filters to the vulnerabilities over time panel', async () => {
      const projectId = 'gid://gitlab/Project/123';
      findFilteredSearch().vm.$emit('filters-changed', { projectId });
      await nextTick();

      expect(getFirstPanel().componentProps.filters).toEqual({ projectId });
    });
  });

  describe('panel component props', () => {
    it('passes filters to the vulnerabilities over time panel component', () => {
      expect(getFirstPanel().componentProps.filters).toEqual({});
    });
  });
});
