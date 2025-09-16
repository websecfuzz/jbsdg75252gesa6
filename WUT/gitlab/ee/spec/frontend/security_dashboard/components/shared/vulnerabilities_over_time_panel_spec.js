import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import VulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_panel.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_vulnerabilities_over_time.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useFakeDate } from 'helpers/fake_date';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('VulnerabilitiesOverTimePanel', () => {
  const todayInIsoFormat = '2020-07-06';
  const ninetyDaysAgoInIsoFormat = '2020-04-07';
  useFakeDate(todayInIsoFormat);

  let wrapper;

  const mockGroupFullPath = 'group/subgroup';
  const mockFilters = { projectId: 'gid://gitlab/Project/123' };

  const defaultMockVulnerabilitiesOverTimeData = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        securityMetrics: {
          vulnerabilitiesOverTime: {
            nodes: [
              {
                date: '2025-06-01',
                bySeverity: [
                  { severity: 'CRITICAL', count: 5 },
                  { severity: 'HIGH', count: 10 },
                  { severity: 'MEDIUM', count: 15 },
                  { severity: 'LOW', count: 8 },
                ],
              },
              {
                date: '2025-06-02',
                bySeverity: [
                  { severity: 'CRITICAL', count: 6 },
                  { severity: 'HIGH', count: 9 },
                  { severity: 'MEDIUM', count: 14 },
                  { severity: 'LOW', count: 7 },
                ],
              },
            ],
          },
        },
      },
    },
  };

  const createComponent = ({ props = {}, mockVulnerabilitiesOverTimeHandler = null } = {}) => {
    const vulnerabilitiesOverTimeHandler =
      mockVulnerabilitiesOverTimeHandler ||
      jest.fn().mockResolvedValue(defaultMockVulnerabilitiesOverTimeData);

    const apolloProvider = createMockApollo([
      [getVulnerabilitiesOverTime, vulnerabilitiesOverTimeHandler],
    ]);

    wrapper = shallowMountExtended(VulnerabilitiesOverTimePanel, {
      apolloProvider,
      propsData: {
        filters: mockFilters,
        ...props,
      },
      provide: {
        groupFullPath: mockGroupFullPath,
      },
    });

    return { vulnerabilitiesOverTimeHandler };
  };

  const findExtendedDashboardPanel = () => wrapper.findComponent(ExtendedDashboardPanel);
  const findVulnerabilitiesOverTimeChart = () =>
    wrapper.findComponent(VulnerabilitiesOverTimeChart);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('passes the correct title to the panels base', () => {
      expect(findExtendedDashboardPanel().props('title')).toBe('Vulnerabilities over time');
    });

    it('renders the vulnerabilities over time chart', () => {
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(true);
    });
  });

  describe('Apollo query', () => {
    it('fetches vulnerabilities over time data when component is created', () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        startDate: ninetyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
      });
    });

    it('passes filters to the GraphQL query', () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent({
        props: {
          filters: { projectId: 'gid://gitlab/Project/456' },
        },
      });

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: 'gid://gitlab/Project/456',
        startDate: ninetyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
      });
    });

    it('does not include projectId when filters are empty', () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent({
        props: {
          filters: {},
        },
      });

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        startDate: ninetyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
      });
    });
  });

  describe('chart data formatting', () => {
    it('correctly formats chart data from the API response', async () => {
      createComponent();
      await waitForPromises();
      await nextTick();

      const expectedChartData = [
        {
          name: 'Critical',
          data: [
            ['2025-06-01', 5],
            ['2025-06-02', 6],
          ],
        },
        {
          name: 'High',
          data: [
            ['2025-06-01', 10],
            ['2025-06-02', 9],
          ],
        },
        {
          name: 'Medium',
          data: [
            ['2025-06-01', 15],
            ['2025-06-02', 14],
          ],
        },
        {
          name: 'Low',
          data: [
            ['2025-06-01', 8],
            ['2025-06-02', 7],
          ],
        },
      ];

      expect(findVulnerabilitiesOverTimeChart().props('chartSeries')).toEqual(expectedChartData);
    });

    it('returns empty chart data when no vulnerabilities data is available', async () => {
      const emptyResponse = {
        data: {
          group: {
            id: 'gid://gitlab/Group/1',
            securityMetrics: {
              vulnerabilitiesOverTime: {
                nodes: [],
              },
            },
          },
        },
      };

      createComponent({
        mockVulnerabilitiesOverTimeHandler: jest.fn().mockResolvedValue(emptyResponse),
      });
      await waitForPromises();

      expect(findVulnerabilitiesOverTimeChart().props('chartSeries')).toEqual([]);
    });
  });

  describe('loading state', () => {
    it('passes loading state to panels base', async () => {
      createComponent();

      expect(findExtendedDashboardPanel().props('loading')).toBe(true);

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('loading')).toBe(false);
    });
  });

  describe('error handling', () => {
    describe.each`
      errorType                   | mockVulnerabilitiesOverTimeHandler
      ${'GraphQL query failures'} | ${jest.fn().mockRejectedValue(new Error('GraphQL query failed'))}
      ${'server error responses'} | ${jest.fn().mockResolvedValue({ errors: [{ message: 'Internal server error' }] })}
    `('$errorType', ({ mockVulnerabilitiesOverTimeHandler }) => {
      beforeEach(async () => {
        createComponent({
          mockVulnerabilitiesOverTimeHandler,
        });

        await waitForPromises();
      });

      it('sets the panel alert state', () => {
        expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      });

      it('does not render the chart component', () => {
        expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      });

      it('renders the correct error message', () => {
        expect(wrapper.text()).toContain('Something went wrong. Please try again.');
      });
    });
  });
});
