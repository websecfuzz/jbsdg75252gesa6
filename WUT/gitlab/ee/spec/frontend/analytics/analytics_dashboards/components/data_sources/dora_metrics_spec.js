import { mockDoraMetricsResponseData } from 'jest/analytics/shared/mock_data';
import fetch from 'ee/analytics/analytics_dashboards/data_sources/dora_metrics';
import { DORA_METRICS_CHARTS_ADDITIONAL_OPTS } from 'ee/analytics/analytics_dashboards/constants';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTION_LAST_7_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import {
  BUCKETING_INTERVAL_DAILY,
  BUCKETING_INTERVAL_MONTHLY,
} from '~/analytics/shared/graphql/constants';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';
import { dataSeries, medianSeries, nullSeries } from '../../mock_data';

describe('Dora Metrics Data Source', () => {
  let res;
  let mockSetVisualizationOverrides;

  const query = { metric: 'lead_time_for_changes', dateRange: DATE_RANGE_OPTION_LAST_180_DAYS };
  const namespace = 'cool namespace';
  const defaultParams = {
    namespace,
    query,
  };

  const mockResolvedQuery = (dora = mockDoraMetricsResponseData) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValueOnce({ data: { group: { dora } } });

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  beforeEach(() => {
    mockSetVisualizationOverrides = jest.fn();
  });

  describe('fetch', () => {
    describe('default', () => {
      describe('with data available', () => {
        beforeEach(async () => {
          mockResolvedQuery();

          res = await fetch({
            namespace,
            query,
            setVisualizationOverrides: mockSetVisualizationOverrides,
          });
        });

        it('returns a single value', () => {
          expect(res).toBe('0.2721');
        });

        it('correctly applies query parameters', () => {
          expectQueryWithVariables({
            startDate: new Date('2020-01-09'),
            endDate: new Date('2020-07-07'),
            fullPath: 'cool namespace',
            interval: 'ALL',
          });
        });

        it('sets the visualization title and icon', () => {
          expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
            visualizationOptionOverrides: { title: 'Last 180 days', titleIcon: 'clock' },
          });
        });
      });

      describe('with no data available', () => {
        it('returns a `-`', async () => {
          mockResolvedQuery({ metrics: [] });
          res = await fetch({ namespace, query });

          expect(res).toBe('-');
        });
      });

      describe('with an unsupported date range', () => {
        beforeEach(() => {
          mockResolvedQuery();
        });

        it('calls setVisualizationOverrides with 180 days', async () => {
          await fetch({
            namespace,
            query: {
              ...query,
              dateRange: '7_5_days',
            },
            setVisualizationOverrides: mockSetVisualizationOverrides,
          });

          expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
            visualizationOptionOverrides: {
              title: 'Last 180 days',
              titleIcon: 'clock',
            },
          });
        });
      });
    });

    describe('queryOverrides', () => {
      it('can override the date range', async () => {
        mockResolvedQuery();
        res = await fetch({
          ...defaultParams,
          queryOverrides: { dateRange: DATE_RANGE_OPTION_LAST_7_DAYS },
        });

        expectQueryWithVariables({
          startDate: new Date('2020-06-30'),
          endDate: new Date('2020-07-07'),
          fullPath: 'cool namespace',
          interval: 'ALL',
        });
      });

      it('can override the namespace', async () => {
        mockResolvedQuery();
        res = await fetch({
          ...defaultParams,
          queryOverrides: {
            namespace: 'cool-namespace/sub-namespace',
          },
        });

        expectQueryWithVariables({
          startDate: new Date('2020-01-09'),
          endDate: new Date('2020-07-07'),
          fullPath: 'cool-namespace/sub-namespace',
          interval: 'ALL',
        });
      });
    });

    describe('with interval=ALL', () => {
      beforeEach(async () => {
        mockResolvedQuery();
        res = await fetch({
          namespace,
          query,
          setVisualizationOverrides: mockSetVisualizationOverrides,
        });
      });

      it('returns a single value', () => {
        expect(res).toBe('0.2721');
      });

      it('sets the title and titleIcon options', () => {
        expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: {
            titleIcon: 'clock',
            title: 'Last 180 days',
          },
        });
      });
    });

    const timeSeriesData = [dataSeries, medianSeries, nullSeries];

    describe.each`
      interval
      ${BUCKETING_INTERVAL_DAILY}
      ${BUCKETING_INTERVAL_MONTHLY}
    `('with interval=$interval', ({ interval }) => {
      beforeEach(async () => {
        mockResolvedQuery();
        res = await fetch({
          namespace,
          query: {
            ...query,
            interval,
          },
          setVisualizationOverrides: mockSetVisualizationOverrides,
        });
      });

      it('returns a time series', () => {
        expect(res).toEqual(timeSeriesData);
      });

      it('returns the data, median and null series', () => {
        expect(timeSeriesData.map(({ name }) => name)).toEqual([
          'Lead time for changes',
          'Median (last 180d)',
          'No merge requests were deployed during this period',
        ]);
      });

      it('calls setVisualizationOverrides', () => {
        expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: {
            ...DORA_METRICS_CHARTS_ADDITIONAL_OPTS[query.metric],
            chartTooltip: { titleFormatter: localeDateFormat.asDate.format },
          },
        });
      });

      describe('no data available', () => {
        beforeEach(async () => {
          mockResolvedQuery({ metrics: [] });
          res = await fetch({
            namespace,
            query: {
              ...query,
              interval,
            },
            setVisualizationOverrides: mockSetVisualizationOverrides,
          });
        });

        it('returns an empty array', () => {
          expect(res).toEqual([]);
        });
      });
    });
  });
});
