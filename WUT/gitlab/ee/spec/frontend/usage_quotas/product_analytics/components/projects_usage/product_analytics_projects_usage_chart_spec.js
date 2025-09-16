import { GlSkeletonLoader } from '@gitlab/ui';
import { GlColumnChart } from '@gitlab/ui/dist/charts';
import ProductAnalyticsProjectsUsageChart from 'ee/usage_quotas/product_analytics/components/projects_usage/product_analytics_projects_usage_chart.vue';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { getProjectUsage } from 'ee_jest/usage_quotas/product_analytics/graphql/mock_data';
import { useFakeDate } from 'helpers/fake_date';

describe('ProductAnalyticsProjectsUsageChart', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockNow = '2023-01-15T12:00:00Z';
  useFakeDate(mockNow);

  const findLoadingState = () => wrapper.findComponent(GlSkeletonLoader);
  const findUsageChart = () => wrapper.findComponent(GlColumnChart);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(ProductAnalyticsProjectsUsageChart, {
      propsData: {
        ...props,
      },
    });
  };

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({
        isLoading: true,
        projectsUsageData: undefined,
      });
    });

    it('renders the loading state', () => {
      expect(findLoadingState().exists()).toBe(true);
    });

    it('does not render the chart', () => {
      expect(findUsageChart().exists()).toBe(false);
    });
  });

  describe('when there is no project data', () => {
    beforeEach(() => {
      createComponent({
        isLoading: false,
        projectsUsageData: [],
      });
    });

    it('does not render the loading state', () => {
      expect(findLoadingState().exists()).toBe(false);
    });

    it('does not render the usage chart', () => {
      expect(findUsageChart().exists()).toBe(false);
    });
  });

  describe('when there is project data', () => {
    beforeEach(() => {
      createComponent(
        {
          isLoading: false,
          projectsUsageData: [
            getProjectUsage({
              id: convertToGraphQLId(TYPENAME_PROJECT, 1),
              name: `test-project`,
              usage: [
                { year: 2023, month: 1, count: 7 },
                { year: 2022, month: 12, count: 10 },
              ],
            }),
          ],
        },
        mountExtended,
      );
    });

    it('does not render the loading state', () => {
      expect(findLoadingState().exists()).toBe(false);
    });

    it('renders the chart', () => {
      expect(findUsageChart().props()).toMatchObject({
        bars: [
          {
            data: [['test-project', 10]],
            name: 'Previous month',
            stack: 'previous',
          },
          {
            data: [['test-project', 7]],
            name: 'Current month to date',
            stack: 'current',
          },
        ],
        xAxisType: 'category',
        xAxisTitle: 'Projects',
        yAxisTitle: 'Events',
      });
    });
  });

  describe('when there is more than the maximum allowed projects', () => {
    beforeEach(() => {
      createComponent(
        {
          isLoading: false,
          projectsUsageData: Array.from({ length: 51 }).map((_, index) =>
            getProjectUsage({
              id: convertToGraphQLId(TYPENAME_PROJECT, index),
              name: `test-project-${index}`,
              usage: [
                { year: 2023, month: 1, count: 7 },
                { year: 2022, month: 12, count: 10 },
              ],
            }),
          ),
        },
        mountExtended,
      );
    });

    it('limits how many projects are rendered', () => {
      const chart = findUsageChart();
      for (const bar of chart.props('bars')) {
        expect(bar.data).toHaveLength(50);
      }

      expect(chart.props('xAxisTitle')).toBe('Projects (50 of 51 shown)');
    });
  });
});
