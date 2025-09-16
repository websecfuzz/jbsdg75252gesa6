import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ProductAnalyticsProjectsUsage from 'ee/usage_quotas/product_analytics/components/projects_usage/product_analytics_projects_usage.vue';
import ProductAnalyticsProjectsUsageChart from 'ee/usage_quotas/product_analytics/components/projects_usage/product_analytics_projects_usage_chart.vue';
import ProductAnalyticsProjectsUsageTable from 'ee/usage_quotas/product_analytics/components/projects_usage/product_analytics_projects_usage_table.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import getGroupCurrentAndPrevProductAnalyticsUsage from 'ee/usage_quotas/product_analytics/graphql/queries/get_group_product_analytics_usage.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getProjectsUsageDataResponse } from 'ee_jest/usage_quotas/product_analytics/graphql/mock_data';
import { useFakeDate } from 'helpers/fake_date';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('ProductAnalyticsProjectsUsage', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findError = () => wrapper.findComponent(GlAlert);
  const findProductAnalyticsProjectsUsageChart = () =>
    wrapper.findComponent(ProductAnalyticsProjectsUsageChart);
  const findProductAnalyticsProjectsUsageTable = () =>
    wrapper.findComponent(ProductAnalyticsProjectsUsageTable);

  const mockProjectsUsageDataHandler = jest.fn();

  const createComponent = () => {
    const mockApollo = createMockApollo([
      [getGroupCurrentAndPrevProductAnalyticsUsage, mockProjectsUsageDataHandler],
    ]);

    wrapper = shallowMountExtended(ProductAnalyticsProjectsUsage, {
      apolloProvider: mockApollo,
      provide: {
        namespacePath: 'some-group',
      },
    });
  };

  afterEach(() => {
    mockProjectsUsageDataHandler.mockReset();
  });

  it('renders a section header', () => {
    createComponent();

    expect(wrapper.text()).toContain('Usage by project');
  });

  describe('when fetching data', () => {
    const mockNow = '2023-01-15T12:00:00Z';
    useFakeDate(mockNow);

    it('requests data from the current and previous months', () => {
      createComponent();

      expect(mockProjectsUsageDataHandler).toHaveBeenCalledWith({
        namespacePath: 'some-group',
        monthSelection: [
          {
            month: 1,
            year: 2023,
          },
          {
            month: 12,
            year: 2022,
          },
        ],
      });
    });

    describe('while loading', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not render an error', () => {
        expect(findError().exists()).toBe(false);
      });

      it('renders the chart loading state', () => {
        expect(findProductAnalyticsProjectsUsageChart().props()).toMatchObject({
          isLoading: true,
        });
      });

      it('renders the usage table loading state', () => {
        expect(findProductAnalyticsProjectsUsageTable().props()).toMatchObject({
          isLoading: true,
        });
      });
    });

    describe('and there is an error', () => {
      const error = new Error('oh no!');

      beforeEach(() => {
        mockProjectsUsageDataHandler.mockRejectedValue(error);
        createComponent();
        return waitForPromises();
      });

      it('does not render the chart', () => {
        expect(findProductAnalyticsProjectsUsageChart().exists()).toBe(false);
      });

      it('does not render the usage table', () => {
        expect(findProductAnalyticsProjectsUsageTable().exists()).toBe(false);
      });

      it('renders an error', () => {
        expect(findError().text()).toContain(
          'Something went wrong while loading product analytics usage data. Refresh the page to try again.',
        );
      });

      it('captures the error in Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException.mock.calls[0][0]).toEqual(error);
      });
    });

    describe('and data has loaded', () => {
      beforeEach(() => {
        mockProjectsUsageDataHandler.mockResolvedValue({ data: getProjectsUsageDataResponse() });
        createComponent();
        return waitForPromises();
      });

      it('does not render an error', () => {
        expect(findError().exists()).toBe(false);
      });

      it('renders the chart', () => {
        expect(findProductAnalyticsProjectsUsageChart().props()).toMatchObject({
          isLoading: false,
          projectsUsageData: [
            {
              name: 'some onboarded project',
              productAnalyticsEventsStored: [{ year: 2023, month: 11, count: 1234 }],
            },
          ],
        });
      });

      it('renders the usage table', () => {
        expect(findProductAnalyticsProjectsUsageTable().props()).toMatchObject({
          isLoading: false,
          projectsUsageData: [
            {
              name: 'some onboarded project',
              productAnalyticsEventsStored: [{ year: 2023, month: 11, count: 1234 }],
            },
          ],
        });
      });
    });
  });
});
