import fetch from 'ee/analytics/analytics_dashboards/data_sources/merge_requests';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import * as utils from 'ee/analytics/analytics_dashboards/components/filters/utils';
import {
  DATE_RANGE_OPTION_LAST_60_DAYS,
  DATE_RANGE_OPTION_LAST_365_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import {
  mockThroughputFiltersQueryObject,
  mockThroughputSearchFilters,
  throughputTableData,
} from 'ee_jest/analytics/merge_request_analytics/mock_data';

const mockPageInfo = {
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: 'this-is-a-start-cursor',
  endCursor: 'this-is-an-end-cursor',
  __typename: 'PageInfo',
};

const mockMergeRequestsResponseData = {
  mergeRequests: {
    nodes: throughputTableData,
    pageInfo: mockPageInfo,
  },
};

const defaultFilters = {
  labels: null,
  notLabels: null,
  sourceBranches: null,
  targetBranches: null,
};

const mockResolvedQuery = ({ mergeRequests = [] } = {}) =>
  jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: { project: { mergeRequests } } });

const expectQueryWithVariables = (variables) =>
  expect(defaultClient.query).toHaveBeenCalledWith(
    expect.objectContaining({
      variables: expect.objectContaining({
        ...defaultFilters,
        ...variables,
      }),
    }),
  );

describe('Merge requests data source', () => {
  let mockSetVisualizationOverrides;
  let res;

  const namespace = 'test-namespace';
  const defaultQueryParams = {
    dateRange: DATE_RANGE_OPTION_LAST_60_DAYS,
  };

  afterEach(() => {
    jest.clearAllMocks();
  });

  beforeEach(() => {
    mockSetVisualizationOverrides = jest.fn();
    jest.spyOn(utils, 'getStartDate').mockReturnValue(new Date('2020-05-13'));
  });

  it('can override default query parameters', async () => {
    jest.spyOn(utils, 'getStartDate').mockReturnValue(new Date('2019-08-07'));
    mockResolvedQuery();

    res = await fetch({
      setVisualizationOverrides: mockSetVisualizationOverrides,
      namespace,
      query: {
        ...defaultQueryParams,
        dateRange: DATE_RANGE_OPTION_LAST_365_DAYS,
      },
      queryOverrides: {
        labels: ['a', 'b'],
        milestoneTitle: '101',
        authorUsername: 'Dr. Gero',
      },
    });

    expectQueryWithVariables({
      fullPath: namespace,
      startDate: new Date('2019-08-07'),
      endDate: new Date('2020-07-07'),
      labels: ['a', 'b'],
      milestoneTitle: '101',
      authorUsername: 'Dr. Gero',
    });

    expect(defaultClient.query).toHaveBeenCalledTimes(1);
  });

  it('can transform search filters into correct query parameters', async () => {
    mockResolvedQuery();

    res = await fetch({
      setVisualizationOverrides: mockSetVisualizationOverrides,
      namespace,
      query: defaultQueryParams,
      filters: {
        searchFilters: mockThroughputSearchFilters,
      },
    });

    expectQueryWithVariables({
      fullPath: namespace,
      startDate: new Date('2020-05-13'),
      endDate: new Date('2020-07-07'),
      ...mockThroughputFiltersQueryObject,
    });

    expect(defaultClient.query).toHaveBeenCalledTimes(1);
  });

  describe('with data available', () => {
    beforeEach(async () => {
      mockResolvedQuery(mockMergeRequestsResponseData);

      res = await fetch({
        setVisualizationOverrides: mockSetVisualizationOverrides,
        namespace,
        query: defaultQueryParams,
      });
    });

    it('sets the correct query parameters', () => {
      expectQueryWithVariables({
        fullPath: namespace,
        startDate: new Date('2020-05-13'),
        endDate: new Date('2020-07-07'),
      });

      expect(defaultClient.query).toHaveBeenCalledTimes(1);
    });

    it('returns data and pagination information', () => {
      expect(res).toMatchObject({
        list: throughputTableData,
        pageInfo: {
          ...mockPageInfo,
          currentPage: 1,
          firstPageSize: 20,
          lastPageSize: null,
          nextPageCursor: '',
          prevPageCursor: '',
        },
      });
    });
  });

  describe('with no data available', () => {
    beforeEach(async () => {
      mockResolvedQuery();

      res = await fetch({
        setVisualizationOverrides: mockSetVisualizationOverrides,
        namespace,
        query: defaultQueryParams,
      });
    });

    it('returns null', () => {
      expect(res).toBeNull();
    });
  });
});
