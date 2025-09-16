import lastWeekData from 'test_fixtures/api/dora/metrics/daily_lead_time_for_changes_for_last_week.json';
import deploymentFrequencyLastWeekData from 'test_fixtures/api/dora/metrics/daily_deployment_frequency_for_last_week.json';
import { secondsToDays } from '~/analytics/shared/utils';
import { buildNullSeries } from 'ee/analytics/shared/utils';
import {
  apiDataToChartSeries,
  seriesToAverageSeries,
  seriesToMedianSeries,
  extractTimeSeriesTooltip,
  formatAsPercentage,
  forecastDataToSeries,
  extractOverviewMetricsQueryParameters,
} from 'ee/analytics/dora/components/util';
import { forecastDataToChartDate } from './helpers';
import { mockLastWeekData, mockLastWeekRawForecastData } from './mock_data';

const NO_DATA_MESSAGE = 'No data available';

describe('ee/analytics/dora/components/util.js', () => {
  describe('apiDataToChartSeries', () => {
    it('transforms the data from the API into data the chart component can use', () => {
      const apiData = [
        // This is the date format we expect from the API
        { value: 5, date: '2015-06-28' },

        // But we should support _any_ date format
        { value: 1, date: '2015-06-28T20:00:00.000-0400' },
        { value: 8, date: '2015-07-01T00:00:00.000Z' },
      ];

      const startDate = new Date(2015, 5, 26, 10);
      const endDate = new Date(2015, 6, 4, 10);
      const chartTitle = 'Chart title';

      const expected = [
        {
          name: chartTitle,
          data: [
            ['Jun 26, 2015', 0],
            ['Jun 27, 2015', 0],
            ['Jun 28, 2015', 5],
            ['Jun 29, 2015', 1],
            ['Jun 30, 2015', 0],
            ['Jul 01, 2015', 8],
            ['Jul 02, 2015', 0],
            ['Jul 03, 2015', 0],
          ],
        },
      ];

      expect(apiDataToChartSeries(apiData, startDate, endDate, chartTitle)).toEqual(expected);
    });
  });

  describe('lead time data', () => {
    it('returns the correct lead time chart data after all processing of the API response', () => {
      const chartData = buildNullSeries({
        seriesData: apiDataToChartSeries(
          lastWeekData,
          new Date(2015, 5, 27, 10),
          new Date(2015, 6, 4, 10),
          'Lead time',
          null,
        ),
        nullSeriesTitle: NO_DATA_MESSAGE,
      });

      expect(chartData).toMatchSnapshot();
    });
  });

  describe('seriesToAverageSeries', () => {
    const seriesName = 'Average';

    it('returns an empty object if chart data is undefined', () => {
      const data = seriesToAverageSeries(undefined, seriesName);

      expect(data).toStrictEqual({});
    });

    it('returns an empty object if chart data is blank', () => {
      const data = seriesToAverageSeries(null, seriesName);

      expect(data).toStrictEqual({});
    });

    it('returns the correct average values', () => {
      const data = seriesToAverageSeries(
        [
          ['Jul 01, 2015', 2],
          ['Jul 02, 2015', 3],
          ['Jul 03, 2015', 4],
        ],
        seriesName,
      );

      expect(data).toStrictEqual({
        name: seriesName,
        data: [
          ['Jul 01, 2015', 3],
          ['Jul 02, 2015', 3],
          ['Jul 03, 2015', 3],
        ],
      });
    });
  });

  describe('seriesToMedianSeries', () => {
    const seriesName = 'Median';

    it('returns an empty object if chart data is undefined', () => {
      const data = seriesToMedianSeries(undefined, seriesName);

      expect(data).toStrictEqual({});
    });

    it('returns an empty object if chart data is blank', () => {
      const data = seriesToMedianSeries(null, seriesName);

      expect(data).toStrictEqual({});
    });

    it('returns the correct median values', () => {
      const data = seriesToMedianSeries(
        [
          ['Jul 01, 2015', 1],
          ['Jul 02, 2015', 3],
          ['Jul 03, 2015', 10],
        ],
        seriesName,
      );

      expect(data).toStrictEqual({
        name: seriesName,
        data: [
          ['Jul 01, 2015', 3],
          ['Jul 02, 2015', 3],
          ['Jul 03, 2015', 3],
        ],
      });
    });
  });

  describe('extractTimeSeriesTooltip', () => {
    const fakeChartTitle = 'cool-chart-title';
    const params = { seriesData: [{ data: ['Apr 7', 5328] }, { data: ['Apr 7', 4000] }, {}] };

    it('displays a humanized version of the time interval in the tooltip', () => {
      const { tooltipValue } = extractTimeSeriesTooltip(params, fakeChartTitle);

      expect(tooltipValue[0].value).toBe('1.5 hours');
      expect(tooltipValue[1].value).toBe('1.1 hours');
    });

    it('will apply a custom formatter when supplied', () => {
      const formatter = jest.fn();

      extractTimeSeriesTooltip(params, fakeChartTitle, formatter);
      expect(formatter).toHaveBeenCalledTimes(2);
    });
  });

  describe('secondsToDays', () => {
    const seconds = 151000;

    it('defaults to a single decimal', () => {
      expect(secondsToDays(seconds)).toBe('1.7');
    });

    it('will format to the specified precision', () => {
      expect(secondsToDays(seconds, 3)).toBe('1.748');
    });
  });

  describe('formatAsPercentage', () => {
    it('returns 0 if given NaN', () => {
      expect(formatAsPercentage(null)).toBe('0.0%');
      expect(formatAsPercentage('a')).toBe('0.0%');
    });

    it('formats valid values', () => {
      expect(formatAsPercentage(0.25)).toBe('25.0%');
      expect(formatAsPercentage('1.86', 0)).toBe('186%');
    });
  });

  describe('forecastDataToSeries', () => {
    let res;

    const forecastResponse = forecastDataToChartDate(
      deploymentFrequencyLastWeekData,
      mockLastWeekRawForecastData,
    );

    beforeEach(() => {
      res = forecastDataToSeries({
        forecastData: mockLastWeekRawForecastData,
        forecastHorizon: 3,
        forecastSeriesLabel: 'Forecast',
        dataSeries: mockLastWeekData,
        endDate: new Date('2015-07-04'),
      });
    });

    it('returns the data series to be displayed in charts', () => {
      expect(res).toEqual(forecastResponse);
    });

    it('includes the last data point from the data series', () => {
      expect(res[0]).toEqual(['Jul 03, 2015', 1]);
    });
  });

  describe('extractOverviewMetricsQueryParameters', () => {
    it('returns empty object when no requestParams property provided', () => {
      expect(extractOverviewMetricsQueryParameters()).toEqual({});
      expect(extractOverviewMetricsQueryParameters({})).toEqual({});
    });

    it.each`
      param           | value           | expected
      ${'start_date'} | ${'2024-01-01'} | ${'startDate'}
      ${'end_date'}   | ${'2024-12-31'} | ${'endDate'}
    `('correctly transforms the $param parameter', ({ param, value, expected }) => {
      const result = extractOverviewMetricsQueryParameters({ requestParams: { [param]: value } });
      expect(result[expected]).toBe(value);
    });
  });
});
