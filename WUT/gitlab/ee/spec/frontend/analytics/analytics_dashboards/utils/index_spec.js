import getCustomizableDashboardQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_customizable_dashboard.query.graphql';
import getAllCustomizableDashboardsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_all_customizable_dashboards.query.graphql';
import * as utils from 'ee/analytics/analytics_dashboards/utils';
import {
  mockFilterOptions,
  TEST_CUSTOM_DASHBOARDS_PROJECT,
  getGraphQLDashboard,
  TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE,
  TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';
import { dashboard } from 'jest/vue_shared/components/customizable_dashboard/mock_data';
import { createMockClient } from 'helpers/mock_apollo_helper';

describe('Analytics dashboard utils', () => {
  describe('getMetricSchema', () => {
    it.each`
      metric                        | expected
      ${'Sessions.count'}           | ${'Sessions'}
      ${'TrackedEvents.count'}      | ${'TrackedEvents'}
      ${'ReturningUsers.something'} | ${'ReturningUsers'}
    `('returns "$expected" for metric "$metric"', ({ metric, expected }) => {
      expect(utils.getMetricSchema(metric)).toBe(expected);
    });

    it.each([undefined, null])('returns undefined for "%s"', (value) => {
      expect(utils.getMetricSchema(value)).toBeUndefined();
    });
  });

  describe('getDimensionsForSchema', () => {
    it('returns an empty array when no schema is provided', () => {
      expect(
        utils.getDimensionsForSchema(null, mockFilterOptions.availableDimensions),
      ).toStrictEqual([]);
    });

    it('returns an empty array when the schema does not match any dimensions', () => {
      expect(
        utils.getDimensionsForSchema('InvalidSchema', mockFilterOptions.availableDimensions),
      ).toStrictEqual([]);
    });

    it('returns the expected dimensions for a schema', () => {
      expect(
        utils
          .getDimensionsForSchema('TrackedEvents', mockFilterOptions.availableDimensions)
          .map(({ name }) => name),
      ).toStrictEqual(['TrackedEvents.pageTitle', 'TrackedEvents.pageUrl']);
    });
  });

  describe('getTimeDimensionForSchema', () => {
    it('returns null when no schema is provided', () => {
      expect(
        utils.getTimeDimensionForSchema(null, mockFilterOptions.availableTimeDimensions),
      ).toBeNull();
    });

    it('returns null when the schema does not match any time dimensions', () => {
      expect(
        utils.getTimeDimensionForSchema('InvalidSchema', mockFilterOptions.availableTimeDimensions),
      ).toBeNull();
    });

    it('returns the expected time dimension for a schema with a single time dimension', () => {
      expect(
        utils.getTimeDimensionForSchema('TrackedEvents', mockFilterOptions.availableTimeDimensions),
      ).toStrictEqual({
        name: 'TrackedEvents.derivedTstamp',
        title: 'Tracked Events Derived Tstamp',
        type: 'time',
        shortTitle: 'Derived Tstamp',
        suggestFilterValues: true,
        isVisible: true,
        public: true,
        primaryKey: false,
      });
    });

    it('returns null for a schema with multiple time dimensions', () => {
      expect(
        utils.getTimeDimensionForSchema('UnknownSchema', [
          { name: 'UnknownSchema.createdAt' },
          { name: 'UnknownSchema.updatedAt' },
        ]),
      ).toBeNull();
    });

    it('returns the "Sessions.startAt" time dimension for the "Sessions" schema', () => {
      expect(
        utils.getTimeDimensionForSchema('Sessions', mockFilterOptions.availableTimeDimensions),
      ).toStrictEqual({
        name: 'Sessions.startAt',
        title: 'Sessions Start at',
        type: 'time',
        shortTitle: 'Start at',
        suggestFilterValues: true,
        isVisible: true,
        public: true,
        primaryKey: false,
      });
    });
  });

  describe('updateApolloCache', () => {
    let apolloClient;
    let mockReadQuery;
    let mockWriteQuery;
    const dashboardSlug = 'analytics_overview';
    const { fullPath } = TEST_CUSTOM_DASHBOARDS_PROJECT;
    const isProject = true;

    const setMockCache = (mockDashboardDetails, mockDashboardsList) => {
      mockReadQuery.mockImplementation(({ query }) => {
        if (query === getCustomizableDashboardQuery) {
          return mockDashboardDetails;
        }
        if (query === getAllCustomizableDashboardsQuery) {
          return mockDashboardsList;
        }

        return null;
      });
    };

    beforeEach(() => {
      apolloClient = createMockClient();

      mockReadQuery = jest.fn();
      mockWriteQuery = jest.fn();
      apolloClient.readQuery = mockReadQuery;
      apolloClient.writeQuery = mockWriteQuery;
    });

    describe('dashboard details cache', () => {
      it('updates an existing dashboard', () => {
        const existingDashboard = getGraphQLDashboard({
          slug: 'some_existing_dash',
          title: 'some existing title',
        });
        const existingDetailsCache = {
          ...TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE.data,
        };
        existingDetailsCache.project.customizableDashboards.nodes = [existingDashboard];

        setMockCache(existingDetailsCache, null);

        utils.updateApolloCache({
          apolloClient,
          slug: existingDashboard.slug,
          dashboard: {
            ...existingDashboard,
            title: 'some new title',
          },
          fullPath,
          isProject,
        });

        expect(mockWriteQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            query: getCustomizableDashboardQuery,
            data: expect.objectContaining({
              project: expect.objectContaining({
                customizableDashboards: expect.objectContaining({
                  nodes: expect.arrayContaining([
                    expect.objectContaining({
                      title: 'some new title',
                    }),
                  ]),
                }),
              }),
            }),
          }),
        );
      });

      it('does not update for new dashboards where cache is empty', () => {
        setMockCache(null, TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data);

        utils.updateApolloCache({
          apolloClient,
          slug: dashboardSlug,
          dashboard,
          fullPath,
          isProject,
        });

        expect(mockWriteQuery).not.toHaveBeenCalledWith(
          expect.objectContaining({ query: getCustomizableDashboardQuery }),
        );
      });
    });

    describe('dashboards list', () => {
      it('adds a new dashboard to the dashboards list', () => {
        setMockCache(null, TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data);

        utils.updateApolloCache({
          apolloClient,
          slug: dashboardSlug,
          dashboard,
          fullPath,
          isProject,
        });

        expect(mockWriteQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            query: getAllCustomizableDashboardsQuery,
            data: expect.objectContaining({
              project: expect.objectContaining({
                customizableDashboards: expect.objectContaining({
                  nodes: expect.arrayContaining([
                    expect.objectContaining({
                      slug: dashboardSlug,
                    }),
                  ]),
                }),
              }),
            }),
          }),
        );
      });

      it('updates an existing dashboard on the dashboards list', () => {
        setMockCache(null, TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data);

        const existingDashboards =
          TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE.data.project.customizableDashboards.nodes;

        const updatedDashboard = {
          ...existingDashboards.at(0),
          title: 'some new title',
        };

        utils.updateApolloCache({
          apolloClient,
          slug: dashboardSlug,
          dashboard: updatedDashboard,
          fullPath,
          isProject,
        });

        expect(mockWriteQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            query: getAllCustomizableDashboardsQuery,
            data: expect.objectContaining({
              project: expect.objectContaining({
                customizableDashboards: expect.objectContaining({
                  nodes: expect.arrayContaining([
                    expect.objectContaining({
                      title: 'some new title',
                    }),
                  ]),
                }),
              }),
            }),
          }),
        );
      });

      it('does not update dashboard list cache when it has not yet been populated', () => {
        setMockCache(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE.data, null);

        utils.updateApolloCache({
          apolloClient,
          slug: dashboardSlug,
          dashboard,
          fullPath,
          isProject,
        });

        expect(mockWriteQuery).not.toHaveBeenCalledWith(
          expect.objectContaining({ query: getAllCustomizableDashboardsQuery }),
        );
      });
    });
  });
});
