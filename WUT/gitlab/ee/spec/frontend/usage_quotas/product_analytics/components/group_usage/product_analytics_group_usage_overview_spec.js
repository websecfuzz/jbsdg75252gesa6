import { useFakeDate } from 'helpers/fake_date';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import ProductAnalyticsGroupUsageOverview from 'ee/usage_quotas/product_analytics/components/group_usage/product_analytics_group_usage_overview.vue';
import StatisticsCard from 'ee/usage_quotas/components/statistics_card.vue';

describe('ProductAnalyticsGroupUsageOverview', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockNow = '2023-01-15T12:00:00Z';
  useFakeDate(mockNow);

  const findStatisticsCard = () => wrapper.findComponent(StatisticsCard);

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(ProductAnalyticsGroupUsageOverview, {
      propsData: {
        ...props,
      },
    });
  };

  it('should render loading indicators', () => {
    createWrapper({ isLoading: true });

    expect(findStatisticsCard().props('loading')).toBe(true);
  });

  describe('once loaded', () => {
    describe('with no events limit set', () => {
      beforeEach(() => {
        createWrapper({
          isLoading: false,
          eventsUsed: 123456,
          storedEventsLimit: null,
        });
      });

      it('should not render statistics card', () => {
        expect(findStatisticsCard().exists()).toBe(false);
      });
    });

    describe('with an events limit set', () => {
      beforeEach(() => {
        createWrapper({
          isLoading: false,
          eventsUsed: 123456,
          storedEventsLimit: 1000000,
        });
      });

      it('should not render loading indicators', () => {
        expect(findStatisticsCard().props('loading')).toBe(false);
      });

      it('should render the statistics card', () => {
        expect(findStatisticsCard().props()).toMatchObject({
          description: 'Events received since Jan 01, 2023',
          percentage: 12,
          totalValue: 1000000,
          usageValue: 123456,
        });
      });
    });
  });
});
