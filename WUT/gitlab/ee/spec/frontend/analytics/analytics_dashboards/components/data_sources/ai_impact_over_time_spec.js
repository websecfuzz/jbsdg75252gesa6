import {
  mockAiMetricsResponseData,
  mockAiMetricsZeroResponseData,
  mockAiMetricsNullResponseData,
} from 'ee_jest/analytics/dashboards/ai_impact/mock_data';
import { AI_METRICS } from '~/analytics/shared/constants';
import fetch from 'ee/analytics/analytics_dashboards/data_sources/ai_impact_over_time';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  LAST_WEEK,
  LAST_30_DAYS,
  LAST_180_DAYS,
} from 'ee/analytics/dora/components/static_data/shared';
import { AI_IMPACT_OVER_TIME_METRICS } from 'ee/analytics/dashboards/ai_impact/constants';

describe('AI Impact Over Time Data Source', () => {
  let res;

  const query = { metric: AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE, dateRange: LAST_30_DAYS };
  const namespace = 'cool namespace';
  const defaultParams = {
    namespace,
    query,
  };

  const mockResolvedQuery = (response = mockAiMetricsResponseData) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValueOnce({ data: { group: response } });

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  describe('fetch', () => {
    describe('default', () => {
      it('correctly applies query parameters', async () => {
        await mockResolvedQuery();
        res = await fetch({ namespace, query });

        expectQueryWithVariables({
          startDate: new Date('2020-06-07'),
          endDate: new Date('2020-07-07'),
          fullPath: namespace,
        });
      });

      describe.each`
        type             | response                         | result
        ${'valid'}       | ${mockAiMetricsResponseData}     | ${'62.5'}
        ${'zero values'} | ${mockAiMetricsZeroResponseData} | ${'-'}
        ${'null values'} | ${mockAiMetricsNullResponseData} | ${'-'}
      `('with $type data', ({ response, result }) => {
        beforeEach(async () => {
          mockResolvedQuery(response);
          res = await fetch({ namespace, query });
        });

        it(`returns ${result}`, () => {
          expect(res).toBe(result);
        });
      });
    });

    describe('setVisualizationOverrides callback', () => {
      describe.each(Object.keys(AI_IMPACT_OVER_TIME_METRICS))('for %s metric', (metric) => {
        let mockSetVisualizationOverrides;

        describe.each`
          description                    | response
          ${'with valid response'}       | ${mockAiMetricsResponseData}
          ${'with null values response'} | ${mockAiMetricsNullResponseData}
          ${'with zeroes response'}      | ${mockAiMetricsZeroResponseData}
        `('$description', ({ response }) => {
          beforeEach(async () => {
            mockSetVisualizationOverrides = jest.fn();

            mockResolvedQuery(response);
            res = await fetch({
              namespace,
              query: { ...defaultParams.query, metric },
              setVisualizationOverrides: mockSetVisualizationOverrides,
            });
          });

          it('will call the setVisualizationOverrides callback with the correct settings', () => {
            expect(mockSetVisualizationOverrides.mock.calls).toMatchSnapshot();
          });
        });
      });
    });

    describe('queryOverrides', () => {
      const mockQuery = (
        dateRange,
        {
          namespace: namespaceParam = 'cool namespace',
          metric = AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE,
        } = {},
      ) => {
        mockResolvedQuery();

        return fetch({
          ...defaultParams,
          query: { ...defaultParams.query, metric },
          queryOverrides: { dateRange, namespace: namespaceParam },
        });
      };

      it('can override the date range', async () => {
        res = await mockQuery(LAST_WEEK);

        expectQueryWithVariables({
          startDate: new Date('2020-06-30'),
          endDate: new Date('2020-07-07'),
          fullPath: namespace,
        });
      });

      it.each`
        metric                                         | result
        ${AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE}      | ${'62.5'}
        ${AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE} | ${'40.0'}
        ${AI_METRICS.DUO_CHAT_USAGE_RATE}              | ${'50.0'}
        ${AI_METRICS.DUO_USAGE_RATE}                   | ${'30.0'}
      `('can override the metric with `$metric`', async ({ metric, result }) => {
        res = await mockQuery(LAST_WEEK, { metric });

        expectQueryWithVariables({
          startDate: new Date('2020-06-30'),
          endDate: new Date('2020-07-07'),
          fullPath: namespace,
        });

        expect(res).toBe(result);
      });

      it('can override the namespace', async () => {
        res = await mockQuery(LAST_WEEK, { namespace: 'cool-namespace/sub-namespace' });

        expectQueryWithVariables({
          startDate: new Date('2020-06-30'),
          endDate: new Date('2020-07-07'),
          fullPath: 'cool-namespace/sub-namespace',
        });
      });

      it('will default to LAST_180_DAYS when given an invalid dateRange', async () => {
        res = await mockQuery('LAST_45_DAYS');

        expectQueryWithVariables({
          startDate: new Date('2020-01-09'),
          endDate: new Date('2020-07-07'),
          fullPath: namespace,
        });

        const defaultRes = await mockQuery(LAST_180_DAYS);
        expect(defaultRes).toEqual(res);
      });
    });
  });
});
