import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  getProjectsUsageDataResponse,
  getProjectUsage,
  getProjectWithYearsUsage,
} from 'ee_jest/usage_quotas/product_analytics/graphql/mock_data';
import { useFakeDate } from 'helpers/fake_date';

import getGroupCurrentAndPrevProductAnalyticsUsage from 'ee/usage_quotas/product_analytics/graphql/queries/get_group_product_analytics_usage.query.graphql';
import ProductAnalyticsGroupUsage from 'ee/usage_quotas/product_analytics/components/group_usage/product_analytics_group_usage.vue';
import ProductAnalyticsGroupMonthlyUsageChart from 'ee/usage_quotas/product_analytics/components/group_usage/product_analytics_group_monthly_usage_chart.vue';
import ProductAnalyticsGroupUsageOverview from 'ee/usage_quotas/product_analytics/components/group_usage/product_analytics_group_usage_overview.vue';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('ProductAnalyticsGroupUsage', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockNow = '2023-01-15T12:00:00Z';
  useFakeDate(mockNow);

  const findError = () => wrapper.findComponent(GlAlert);
  const findUsageOverview = () => wrapper.findComponent(ProductAnalyticsGroupUsageOverview);
  const findChart = () => wrapper.findComponent(ProductAnalyticsGroupMonthlyUsageChart);
  const findUsageQuotaLearnMoreLink = () =>
    wrapper.findByTestId('product-analytics-usage-quota-learn-more');
  const findDataRetentionLearnMoreLink = () =>
    wrapper.findByTestId('product-analytics-data-retention-learn-more');

  const mockProjectsUsageDataHandler = jest.fn();

  const createComponent = ({ glFeatures } = {}) => {
    const mockApollo = createMockApollo([
      [getGroupCurrentAndPrevProductAnalyticsUsage, mockProjectsUsageDataHandler],
    ]);

    wrapper = shallowMountExtended(ProductAnalyticsGroupUsage, {
      apolloProvider: mockApollo,
      provide: {
        namespacePath: 'some-group',
        glFeatures: {
          productAnalyticsUsageQuotaAnnualData: true,
          ...glFeatures,
        },
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  afterEach(() => {
    mockProjectsUsageDataHandler.mockReset();
  });

  it('renders a section header', () => {
    createComponent();

    expect(findUsageQuotaLearnMoreLink().attributes('href')).toBe(
      '/help/development/internal_analytics/product_analytics#view-product-analytics-usage-quota',
    );
  });

  it('specified the data retention policy', () => {
    createComponent();

    expect(wrapper.text()).toContain(
      'If GitLab manages your cluster, then GitLab retains your analytics data for 1 year.',
    );
    expect(findDataRetentionLearnMoreLink().attributes('href')).toBe(
      '/help/development/internal_analytics/product_analytics#product-analytics-provider',
    );
  });

  describe('when fetching data', () => {
    describe('when "product_analytics_usage_quota_annual_data" feature flag is enabled', () => {
      it('requests data from the last 12 months', () => {
        createComponent({ glFeatures: { productAnalyticsUsageQuotaAnnualData: true } });

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
            {
              month: 11,
              year: 2022,
            },
            {
              month: 10,
              year: 2022,
            },
            {
              month: 9,
              year: 2022,
            },
            {
              month: 8,
              year: 2022,
            },
            {
              month: 7,
              year: 2022,
            },
            {
              month: 6,
              year: 2022,
            },
            {
              month: 5,
              year: 2022,
            },
            {
              month: 4,
              year: 2022,
            },
            {
              month: 3,
              year: 2022,
            },
            {
              month: 2,
              year: 2022,
            },
          ],
        });
      });
    });

    describe('when "product_analytics_usage_quota_annual_data" feature flag is disabled', () => {
      it('requests data from the last 2 months', () => {
        createComponent({ glFeatures: { productAnalyticsUsageQuotaAnnualData: false } });

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
    });

    describe('while loading', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not render an error', () => {
        expect(findError().exists()).toBe(false);
      });

      it('renders the chart loading state', () => {
        expect(findChart().props('isLoading')).toBe(true);
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
        expect(findChart().exists()).toBe(false);
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

    describe('and the data has loaded', () => {
      describe.each`
        scenario                                        | projects
        ${'with no projects'}                           | ${[]}
        ${'with no product analytics enabled projects'} | ${[getProjectUsage({ id: 1, name: 'not onboarded', usage: [{ year: 2023, month: 1, count: null }] })]}
      `('$scenario', ({ projects }) => {
        beforeEach(() => {
          mockProjectsUsageDataHandler.mockResolvedValue({
            data: getProjectsUsageDataResponse(projects),
          });
          createComponent();
          return waitForPromises();
        });

        it('does not render an error', () => {
          expect(findError().exists()).toBe(false);
        });

        it('does not render the chart loading state', () => {
          expect(findChart().props('isLoading')).toBe(false);
        });

        it('emits "no-projects" event', () => {
          expect(wrapper.emitted('no-projects')).toHaveLength(1);
        });
      });

      describe('with one project', () => {
        beforeEach(() => {
          mockProjectsUsageDataHandler.mockResolvedValue({
            data: getProjectsUsageDataResponse([getProjectWithYearsUsage()]),
          });
          createComponent();
          return waitForPromises();
        });

        it('does not render an error', () => {
          expect(findError().exists()).toBe(false);
        });

        it('renders the chart', () => {
          expect(findChart().props()).toMatchObject({
            isLoading: false,
            monthlyTotals: [
              ['Feb 2022', 1],
              ['Mar 2022', 1],
              ['Apr 2022', 1],
              ['May 2022', 1],
              ['Jun 2022', 1],
              ['Jul 2022', 1],
              ['Aug 2022', 1],
              ['Sep 2022', 1],
              ['Oct 2022', 1],
              ['Nov 2022', 1],
              ['Dec 2022', 1],
              ['Jan 2023', 1],
            ],
          });
        });
      });

      describe('with many projects', () => {
        beforeEach(() => {
          mockProjectsUsageDataHandler.mockResolvedValue({
            data: getProjectsUsageDataResponse([
              getProjectWithYearsUsage({
                id: 1,
              }),
              getProjectWithYearsUsage({ id: 2 }),
            ]),
          });
          createComponent();
          return waitForPromises();
        });

        it('renders the chart with correctly summed counts', () => {
          expect(findChart().props()).toMatchObject({
            isLoading: false,
            monthlyTotals: [
              ['Feb 2022', 2],
              ['Mar 2022', 2],
              ['Apr 2022', 2],
              ['May 2022', 2],
              ['Jun 2022', 2],
              ['Jul 2022', 2],
              ['Aug 2022', 2],
              ['Sep 2022', 2],
              ['Oct 2022', 2],
              ['Nov 2022', 2],
              ['Dec 2022', 2],
              ['Jan 2023', 2],
            ],
          });
        });
      });
    });
  });

  describe('usage overview', () => {
    describe('when "productAnalyticsBilling" feature flag is disabled', () => {
      describe('while loading', () => {
        beforeEach(() => {
          mockProjectsUsageDataHandler.mockResolvedValue({
            data: getProjectsUsageDataResponse([getProjectWithYearsUsage()]),
          });
          createComponent({ glFeatures: { productAnalyticsBilling: false } });
        });

        it('does not render the usage overview loading state', () => {
          expect(findUsageOverview().exists()).toBe(false);
        });
      });

      describe('when there is data', () => {
        beforeEach(() => {
          mockProjectsUsageDataHandler.mockResolvedValue({
            data: getProjectsUsageDataResponse([getProjectWithYearsUsage()]),
          });
          createComponent({ glFeatures: { productAnalyticsBilling: false } });
          return waitForPromises();
        });

        it('does not render usage overview', () => {
          expect(findUsageOverview().exists()).toBe(false);
        });
      });
    });

    describe('when "productAnalyticsBilling" feature flag is enabled', () => {
      describe('while loading', () => {
        beforeEach(() => {
          mockProjectsUsageDataHandler.mockResolvedValue({
            data: getProjectsUsageDataResponse([getProjectWithYearsUsage()]),
          });
          createComponent({ glFeatures: { productAnalyticsBilling: true } });
        });

        it('renders the usage overview loading state', () => {
          expect(findUsageOverview().props('isLoading')).toBe(true);
        });
      });

      describe('when there is an error', () => {
        beforeEach(() => {
          mockProjectsUsageDataHandler.mockRejectedValue(new Error('oh no!'));
          createComponent({ glFeatures: { productAnalyticsBilling: true } });
          return waitForPromises();
        });

        it('does not render usage overview', () => {
          expect(findUsageOverview().exists()).toBe(false);
        });
      });

      describe('when there is data', () => {
        beforeEach(() => {
          mockProjectsUsageDataHandler.mockResolvedValue({
            data: getProjectsUsageDataResponse([getProjectWithYearsUsage()]),
          });
          createComponent({ glFeatures: { productAnalyticsBilling: true } });
          return waitForPromises();
        });

        it('renders the usage overview', () => {
          expect(findUsageOverview().props()).toMatchObject({
            isLoading: false,
            eventsUsed: 1,
            storedEventsLimit: 1000000,
          });
        });
      });
    });
  });
});
