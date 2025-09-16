import fetch from 'ee/analytics/analytics_dashboards/data_sources/mean_time_to_merge';
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

const mockResolvedQuery = (resp = {}) =>
  jest.spyOn(api, 'queryThroughputData').mockResolvedValue(resp);

const expectQueryWithVariables = (variables) =>
  expect(api.queryThroughputData).toHaveBeenCalledWith(expect.objectContaining(variables));

describe('Mean time to merge data source', () => {
  let res;

  const namespace = 'test-namespace';
  const defaultQueryParams = {
    dateRange: DATE_RANGE_OPTION_LAST_60_DAYS,
  };

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('can override default query parameters', async () => {
    jest.spyOn(utils, 'getStartDate').mockReturnValue(new Date('2019-08-07'));
    mockResolvedQuery();

    res = await fetch({
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
      mockResolvedQuery(mockQueryThroughputDataResponse);

      res = await fetch({ namespace, query: defaultQueryParams });
    });

    it('returns a single value representing the mean time to merge', () => {
      expect(res).toEqual(2);
    });
  });

  describe('no data available', () => {
    beforeEach(async () => {
      mockResolvedQuery();

      res = await fetch({ namespace });
    });

    it('returns a "-"', () => {
      expect(res).toEqual('-');
    });
  });
});
