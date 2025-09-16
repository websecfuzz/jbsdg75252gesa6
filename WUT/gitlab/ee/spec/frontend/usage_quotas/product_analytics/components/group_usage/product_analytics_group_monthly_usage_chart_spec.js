import { GlSkeletonLoader } from '@gitlab/ui';
import { GlAreaChart } from '@gitlab/ui/dist/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import ProductAnalyticsGroupMonthlyUsageChart from 'ee/usage_quotas/product_analytics/components/group_usage/product_analytics_group_monthly_usage_chart.vue';

describe('ProductAnalyticsGroupMonthlyUsageChart', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findChart = () => wrapper.findComponent(GlAreaChart);

  const createComponent = (props = { isLoading: false }) => {
    wrapper = shallowMountExtended(ProductAnalyticsGroupMonthlyUsageChart, {
      propsData: {
        ...props,
      },
    });
  };

  it('renders a section header', () => {
    createComponent();

    expect(wrapper.text()).toContain('Usage by month');
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true });
    });

    it('renders the loading state', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not render the chart', () => {
      expect(findChart().exists()).toBe(false);
    });
  });

  describe('once loaded', () => {
    const monthlyTotals = [['Nov 2023', 1234]];

    beforeEach(() => {
      createComponent({ isLoading: false, monthlyTotals });
    });

    it('does not render the loading state', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('renders the chart', () => {
      expect(findChart().props()).toMatchObject({
        data: [
          {
            name: 'Analytics events by month',
            data: [['Nov 2023', 1234]],
          },
        ],
      });
    });
  });
});
