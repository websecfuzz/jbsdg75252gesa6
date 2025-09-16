import fetch from 'ee/analytics/analytics_dashboards/data_sources/merge_request_counts';
import * as api from 'ee/analytics/merge_request_analytics/api';
import * as utils from 'ee/analytics/analytics_dashboards/components/filters/utils';
import {
  DATE_RANGE_OPTION_LAST_60_DAYS,
  DATE_RANGE_OPTION_LAST_365_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import {
  mockThroughputFiltersQueryObject,
  mockThroughputSearchFilters,
} from 'ee_jest/analytics/merge_request_analytics/mock_data';
import { mockQueryThroughputDataResponse } from '../../mock_data';

const mockMRCountsResponse = [
  {
    data: [
      ['Jul 2020', 8],
      ['Jun 2020', 0],
      ['May 2020', 0],
    ],
    name: 'Merge Requests merged',
  },
];

const mockResolvedQuery = (resp = mockQueryThroughputDataResponse) =>
  jest.spyOn(api, 'queryThroughputData').mockResolvedValue(resp);

const expectQueryWithVariables = (variables) =>
  expect(api.queryThroughputData).toHaveBeenCalledWith(expect.objectContaining(variables));

describe('Merge request counts data source', () => {
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
      namespace,
      startDate: new Date('2019-08-07'),
      endDate: new Date('2020-07-07'),
      labels: ['a', 'b'],
      milestoneTitle: '101',
      authorUsername: 'Dr. Gero',
    });
  });

  it('can transform search filters into correct query parameters', async () => {
    jest.spyOn(utils, 'getStartDate').mockReturnValue(new Date('2020-05-08'));
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
      namespace,
      startDate: new Date('2020-05-08'),
      endDate: new Date('2020-07-07'),
      ...mockThroughputFiltersQueryObject,
    });
  });

  describe('with data available', () => {
    beforeEach(async () => {
      mockResolvedQuery();

      res = await fetch({
        setVisualizationOverrides: mockSetVisualizationOverrides,
        namespace,
        query: defaultQueryParams,
      });
    });

    it('returns each interval in the result', () => {
      const intervalNames = res[0].data.map(([name]) => name);
      expect(intervalNames).toEqual(['Jul 2020', 'Jun 2020', 'May 2020']);
    });

    it('returns a data series for MR counts', async () => {
      mockResolvedQuery();

      res = await fetch({
        namespace,
        query: defaultQueryParams,
      });

      expect(res).toMatchObject(mockMRCountsResponse);
    });
  });

  describe('no data available', () => {
    beforeEach(async () => {
      mockResolvedQuery({});

      res = await fetch({
        setVisualizationOverrides: mockSetVisualizationOverrides,
        namespace,
        query: defaultQueryParams,
      });
    });

    it('returns an empty object', () => {
      expect(res).toEqual({});
    });
  });
});
