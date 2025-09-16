import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTableLite, GlButton } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  getLocationHash,
  queryToObject,
  setUrlParams,
  updateHistory,
} from '~/lib/utils/url_utility';
import InventoryDashboard from 'ee/security_inventory/components/inventory_dashboard.vue';
import RecursiveBreadcrumbs from 'ee/security_inventory/components/recursive_breadcrumbs.vue';
import VulnerabilityIndicator from 'ee/security_inventory/components/vulnerability_indicator.vue';
import GroupToolCoverageIndicator from 'ee/security_inventory/components/group_tool_coverage_indicator.vue';
import ProjectToolCoverageIndicator from 'ee/security_inventory/components/project_tool_coverage_indicator.vue';
import SubgroupsAndProjectsQuery from 'ee/security_inventory/graphql/subgroups_and_projects.query.graphql';
import SubgroupSidebar from 'ee/security_inventory/components/sidebar/subgroup_sidebar.vue';
import EmptyState from 'ee/security_inventory/components/empty_state.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import vulnerabilityCell from 'ee/security_inventory/components/vulnerability_cell.vue';
import ToolCoverageCell from 'ee/security_inventory/components/tool_coverage_cell.vue';
import ActionCell from 'ee/security_inventory/components/action_cell.vue';
import SecurityInventoryTable from 'ee/security_inventory/components/security_inventory_table.vue';
import InventoryDashboardFilteredSearchBar from 'ee/security_inventory/components/inventory_dashboard_filtered_search_bar.vue';
import { subgroupsAndProjects } from '../mock_data';
import { createGroupResponse, createPaginatedHandler } from '../mock_pagination_helpers';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility', () => ({
  getLocationHash: jest.fn().mockReturnValue(''),
  PATH_SEPARATOR: '/',
  queryToObject: jest.fn().mockReturnValue({}),
  setUrlParams: jest.fn().mockReturnValue(''),
  updateHistory: jest.fn(),
}));
jest.mock('ee/security_inventory/components/recursive_breadcrumbs.vue', () => ({
  name: 'RecursiveBreadcrumbs',
  props: ['currentPath', 'groupFullPath'],
  render() {},
}));

const setupDefaultUrlMocks = () => {
  getLocationHash.mockReturnValue('');
  queryToObject.mockReturnValue({});
  setUrlParams.mockReturnValue('');
  updateHistory.mockImplementation(() => {});
};

describe('InventoryDashboard', () => {
  let wrapper;
  let apolloProvider;
  let requestHandler = '';

  const childrenResolver = jest.fn().mockResolvedValue(subgroupsAndProjects);
  const mockChildren = [
    ...subgroupsAndProjects.data.group.descendantGroups.nodes,
    ...subgroupsAndProjects.data.group.projects.nodes,
  ];

  const defaultProvide = {
    groupFullPath: 'group/project',
    newProjectPath: '/new',
  };

  const createComponentFactory =
    (mountFn = shallowMountExtended) =>
    async ({ resolver = childrenResolver } = {}) => {
      requestHandler = resolver;
      apolloProvider = createMockApollo([[SubgroupsAndProjectsQuery, resolver]]);
      wrapper = mountFn(InventoryDashboard, {
        apolloProvider,
        provide: defaultProvide,
        stubs: {
          SubgroupSidebar: stubComponent(SubgroupSidebar),
          InventoryDashboardFilteredSearchBar: stubComponent(InventoryDashboardFilteredSearchBar),
          RecursiveBreadcrumbs: stubComponent(RecursiveBreadcrumbs, {
            props: ['currentPath', 'groupFullPath'],
          }),
        },
      });
      await waitForPromises();
    };

  const createComponent = createComponentFactory();
  const createFullComponent = createComponentFactory(mountExtended);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findEmptyState = () => wrapper.findComponent(EmptyState);
  const findTableRows = () => findTable().findAll('tbody tr');
  const findNthTableRow = (n) => findTableRows().at(n);
  const findBreadcrumb = () => wrapper.findComponent(RecursiveBreadcrumbs);
  const findSidebar = () => wrapper.findComponent(SubgroupSidebar);
  const findSidebarToggleButton = () => wrapper.findComponent(GlButton);
  const findInventoryTable = () => wrapper.findComponent(SecurityInventoryTable);
  const loadMoreButton = () => wrapper.findByTestId('load-more-button');
  const findFilteredSearchBar = () => wrapper.findComponent(InventoryDashboardFilteredSearchBar);

  /* eslint-disable no-underscore-dangle */
  const getIndexByType = (children, type) => {
    return children.findIndex((child) => child.__typename === type);
  };
  /* eslint-enable no-underscore-dangle */

  beforeEach(async () => {
    setupDefaultUrlMocks();
    await createComponent();
  });

  it('displays default state correctly', () => {
    expect(wrapper.exists()).toBe(true);

    expect(findEmptyState().exists()).toBe(false);
    expect(findInventoryTable().exists()).toBe(true);
    expect(findInventoryTable().props('isLoading')).toBe(false);
    expect(findFilteredSearchBar().exists()).toBe(true);
  });

  describe('Loading state', () => {
    beforeEach(async () => {
      const mockHandler = jest.fn().mockImplementation(() => new Promise(() => {}));
      await createComponent({ resolver: mockHandler });
    });

    it('sets loading state correctly', () => {
      expect(findInventoryTable().props('isLoading')).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe('Empty state', () => {
    it('displays empty state when there are no children', async () => {
      const emptyResolver = jest.fn().mockResolvedValue({
        data: { group: { descendantGroups: { nodes: [] }, projects: { nodes: [] } } },
      });
      await createComponent({ resolver: emptyResolver });
      await waitForPromises();

      expect(findEmptyState().exists()).toBe(true);
    });
  });

  describe('Table rendering', () => {
    const groupIndex = getIndexByType(mockChildren, 'Group');
    const projectIndex = getIndexByType(mockChildren, 'Project');

    beforeEach(async () => {
      await createFullComponent();
    });

    it('renders the GlTableLite component with correct fields', () => {
      expect(findTable().exists()).toBe(true);
      expect(findTable().props('fields')).toHaveLength(4);
      expect(
        findTable()
          .props('fields')
          .map((field) => field.key),
      ).toEqual(['name', 'vulnerabilities', 'toolCoverage', 'actions']);
    });

    it('renders correct values in table cells for projects and subgroups', () => {
      expect(findTableRows()).toHaveLength(mockChildren.length);

      const nameCell = findNthTableRow(groupIndex).findComponent(NameCell);
      expect(nameCell.exists()).toBe(true);
      expect(nameCell.text()).toContain(mockChildren[0].name);

      const vulnerabilitycell = findNthTableRow(groupIndex).findComponent(vulnerabilityCell);
      expect(vulnerabilitycell.exists()).toBe(true);
      expect(vulnerabilitycell.text()).toContain('80');

      const toolCoverageCell = findNthTableRow(groupIndex).findComponent(ToolCoverageCell);
      expect(toolCoverageCell.exists()).toBe(true);

      const actionCell = findNthTableRow(projectIndex).findComponent(ActionCell);
      expect(actionCell.exists()).toBe(true);
    });

    it('renders correct elements for projects and subgroups', () => {
      const subgroupLink = findNthTableRow(groupIndex).findComponent({ name: 'gl-link' });
      expect(subgroupLink.exists()).toBe(true);
      expect(subgroupLink.attributes('href')).toBe(`#${mockChildren[groupIndex].fullPath}`);

      const projectDiv = findNthTableRow(projectIndex).find('div');
      expect(projectDiv.exists()).toBe(true);
      expect(projectDiv.text()).toContain(mockChildren[projectIndex].name);
    });

    it('renders the vulnerability indicator for projects and subgroups', () => {
      expect(
        findNthTableRow(projectIndex).findComponent(VulnerabilityIndicator).props('counts'),
      ).toStrictEqual({
        critical: 10,
        high: 5,
        low: 4,
        info: 0,
        medium: 48,
        unknown: 7,
        updatedAt: '2025-01-01T00:00:00Z',
      });
      expect(
        findNthTableRow(groupIndex).findComponent(VulnerabilityIndicator).props('counts'),
      ).toStrictEqual({
        critical: 10,
        high: 10,
        low: 10,
        info: 10,
        medium: 20,
        unknown: 20,
        updatedAt: '2025-01-01T00:00:00Z',
      });
    });

    it('renders tool coverage indicators for projects and subgroups', async () => {
      await createFullComponent();
      expect(
        findNthTableRow(projectIndex).findComponent(ProjectToolCoverageIndicator).props('item')
          .analyzerStatuses,
      ).toEqual([
        {
          analyzerType: 'SAST',
          buildId: 'gid://git/path/123',
          lastCall: '2025-01-01T00:00:00Z',
          status: 'SUCCESS',
          updatedAt: '2025-01-01T00:00:00Z',
        },
      ]);
      expect(findNthTableRow(groupIndex).findComponent(GroupToolCoverageIndicator).exists()).toBe(
        true,
      );
    });
  });

  describe('Subgroup sidebar', () => {
    it('can be toggled with the sidebar button', async () => {
      await createComponent();

      expect(findSidebar().exists()).toBe(true);

      findSidebarToggleButton().vm.$emit('click');
      await nextTick();

      expect(findSidebar().exists()).toBe(false);
    });

    it('persists visible state through page reloads', async () => {
      createFullComponent();

      findSidebarToggleButton().vm.$emit('click');
      await nextTick();

      expect(findSidebar().exists()).toBe(false);

      wrapper.destroy();
      createFullComponent();
      await nextTick();

      expect(findSidebar().exists()).toBe(false);
    });
  });

  describe('Error handling', () => {
    it('captures exception in Sentry when an unexpected error occurs', async () => {
      jest.spyOn(Sentry, 'captureException');
      const mockErrorResolver = jest.fn().mockRejectedValue(new Error('Unexpected error'));

      await createComponent({ resolver: mockErrorResolver });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'An error occurred while fetching subgroups and projects. Please try again.',
        }),
      );

      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Unexpected error'));
    });
  });

  describe('opening subgroup details', () => {
    it('refetches data when URL hash changes', async () => {
      const newFullPath = 'new-group';
      getLocationHash.mockReturnValue(newFullPath);

      await createComponent();
      expect(requestHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath: newFullPath,
        }),
      );
    });

    it('fallback to groupFullPath when hash is removed', async () => {
      getLocationHash.mockReturnValue('');

      await createComponent();
      expect(requestHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath: defaultProvide.groupFullPath,
        }),
      );
    });
  });

  describe('RecursiveBreadcrumbs', () => {
    it('renders component with correct props', () => {
      expect(findBreadcrumb().props()).toStrictEqual({
        groupFullPath: 'group/project',
        currentPath: 'group/project',
      });
    });

    it('updates props when activeFullPath changes', async () => {
      getLocationHash.mockReturnValue('group/project/subgroup');
      await createComponent();

      expect(findBreadcrumb().props()).toStrictEqual({
        groupFullPath: 'group/project',
        currentPath: 'group/project/subgroup',
      });
    });
  });

  describe('Load more functionality', () => {
    it('does not render the Load more button by default', () => {
      expect(loadMoreButton().exists()).toBe(false);
    });

    it('shows Load more button when more subgroups are available', async () => {
      const resolver = jest.fn().mockResolvedValue(
        createGroupResponse({
          subgroupsPageInfo: { hasNextPage: true, endCursor: 'abc123' },
        }),
      );

      await createComponent({ resolver });
      await waitForPromises();

      expect(loadMoreButton().exists()).toBe(true);
    });

    it('shows Load more button when more projects are available and subgroups are fully loaded', async () => {
      const resolver = jest.fn().mockResolvedValue(
        createGroupResponse({
          subgroups: [],
          subgroupsPageInfo: { hasNextPage: false, endCursor: null },
          projectsPageInfo: { hasNextPage: true, endCursor: 'def456' },
        }),
      );

      await createComponent({ resolver });
      await waitForPromises();

      expect(loadMoreButton().exists()).toBe(true);
    });

    it('fetches more projects when Load more button is clicked during project pagination', async () => {
      const handler = createPaginatedHandler({
        first: {
          subgroups: [],
          subgroupsPageInfo: { hasNextPage: false, endCursor: null },
          projectsPageInfo: { hasNextPage: true, endCursor: 'project-cursor-123' },
        },
        second: {
          projects: [],
          projectsPageInfo: { hasNextPage: false, endCursor: null },
        },
      });

      await createComponent({ resolver: handler });
      await waitForPromises();

      loadMoreButton().vm.$emit('click');
      await waitForPromises();

      expect(handler.mock.calls[1][0]).toEqual({
        fullPath: defaultProvide.groupFullPath,
        subgroupsFirst: 0,
        subgroupsAfter: null,
        projectsFirst: 20,
        projectsAfter: 'project-cursor-123',
        hasSearch: false,
        search: '',
      });
    });

    it('fetches more subgroups when Load more button is clicked during subgroup pagination', async () => {
      const handler = createPaginatedHandler({
        first: {
          subgroupsPageInfo: { hasNextPage: true, endCursor: 'subgroup-cursor-999' },
          projects: [],
        },
        second: {
          subgroups: [],
          subgroupsPageInfo: { hasNextPage: false, endCursor: null },
          projects: [],
        },
      });

      await createComponent({ resolver: handler });
      await waitForPromises();

      loadMoreButton().vm.$emit('click');
      await waitForPromises();

      expect(handler.mock.calls[1][0]).toEqual({
        fullPath: defaultProvide.groupFullPath,
        subgroupsFirst: 20,
        subgroupsAfter: 'subgroup-cursor-999',
        projectsFirst: 0,
        projectsAfter: null,
        hasSearch: false,
        search: '',
      });
    });
  });

  describe('filtered search', () => {
    it('passes the filters to the filtered search bar', async () => {
      queryToObject.mockReturnValue({ search: 'test-search' });
      await createComponent();

      expect(findFilteredSearchBar().props('initialFilters')).toEqual({ search: 'test-search' });
    });

    it('passes the namespace to the filtered search bar', async () => {
      getLocationHash.mockReturnValue('group/project');
      await createComponent();

      expect(findFilteredSearchBar().props('namespace')).toBe('group/project');
    });

    it('updates query variables when filter changes', async () => {
      const searchParams = { search: 'test query' };
      await createFullComponent();

      findFilteredSearchBar().vm.$emit('filterSubgroupsAndProjects', searchParams);
      await nextTick();
      expect(requestHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          hasSearch: true,
          search: 'test query',
        }),
      );
    });

    it('preserves hash when updating URL with search parameters', async () => {
      getLocationHash.mockReturnValue('group/path');
      setUrlParams.mockReturnValue('http://localhost?search=test');

      findFilteredSearchBar().vm.$emit('filterSubgroupsAndProjects', { search: 'test' });
      await nextTick();
      expect(updateHistory).toHaveBeenCalledWith({
        url: expect.stringContaining('#group/path'),
      });
    });

    it('sets hasSearch flag based on filter value', async () => {
      findFilteredSearchBar().vm.$emit('filterSubgroupsAndProjects', { search: 'test' });
      await nextTick();
      findFilteredSearchBar().vm.$emit('filterSubgroupsAndProjects', { search: '' });
      await nextTick();
      expect(requestHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          hasSearch: false,
        }),
      );
    });

    it('includes hasSearch in query variables', async () => {
      await createComponent();
      findFilteredSearchBar().vm.$emit('filterSubgroupsAndProjects', { search: 'test' });

      await nextTick();
      expect(requestHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          hasSearch: true,
          search: 'test',
        }),
      );
    });
  });
});
