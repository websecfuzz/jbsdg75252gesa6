import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import MockAdapter from 'axios-mock-adapter';
import { shallowMount } from '@vue/test-utils';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_NOT_FOUND } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createdAfter, createdBefore } from 'jest/analytics/cycle_analytics/mock_data';
import DurationChartLoader from 'ee/analytics/cycle_analytics/components/duration_charts/duration_chart_loader.vue';
import StageChart from 'ee/analytics/cycle_analytics/components/duration_charts/stage_chart.vue';
import StageScatterChart from 'ee/analytics/cycle_analytics/components/duration_charts/stage_scatter_chart.vue';
import OverviewChart from 'ee/analytics/cycle_analytics/components/duration_charts/overview_chart.vue';
import getValueStreamStageMetricsQuery from 'ee/analytics/cycle_analytics/graphql/queries/get_value_stream_stage_metrics.query.graphql';
import { createAlert } from '~/alert';
import {
  allowedStages as stages,
  transformedDurationData,
  durationOverviewChartPlottableData,
  endpoints,
  valueStreams,
  mockProjectValueStreamStageMetricsResponse,
  mockGroupValueStreamStageMetricsResponse,
  mockValueStreamStageMetricsNoDataResponse,
  mockProjectValueStreamStageMetricsPaginatedResponse,
  mockGroupValueStreamStageMetricsPaginatedResponse,
} from '../../mock_data';

Vue.use(Vuex);
Vue.use(VueApollo);

jest.mock('~/alert');

describe('DurationChartLoader', () => {
  let wrapper;
  let mock;
  let valueStreamStageMetricsQueryHandler;

  const [valueStream] = valueStreams;
  const [selectedStage] = stages;
  const namespacePath = 'fake/group/path';
  const namespaceRestApiRequestPath = 'fake/group/rest-api-path';
  const namespace = {
    name: 'GitLab Org',
    path: namespacePath,
    restApiRequestPath: namespaceRestApiRequestPath,
  };

  const cycleAnalyticsRequestParams = {
    project_ids: null,
    created_after: '2019-12-11',
    created_before: '2020-01-10',
    author_username: null,
    milestone_title: null,
    assignee_username: null,
    'not[label_name]': null,
  };

  const gqlTransformedFilters = {
    authorUsername: null,
    assigneeUsernames: null,
    milestoneTitle: null,
    not: {
      labelNames: null,
    },
  };

  const defaultValueStreamStageMetricsParams = (isProject) => ({
    fullPath: namespacePath,
    isProject,
    valueStreamId: `gid://gitlab/Analytics::CycleAnalytics::ValueStream/${valueStream.id}`,
    stageId: `gid://gitlab/Analytics::CycleAnalytics::Stage/${selectedStage.id}`,
    startDate: createdAfter,
    endDate: createdBefore,
    ...gqlTransformedFilters,
  });

  const createWrapper = ({
    isOverviewStageSelected = true,
    isProjectNamespace = false,
    features = {},
    valueStreamStageMetricsResponseHandler,
  } = {}) => {
    const store = new Vuex.Store({
      state: {
        selectedStage,
        createdAfter,
        createdBefore,
        namespace: {
          ...namespace,
          type: isProjectNamespace ? 'Project' : 'Group',
        },
      },
      getters: {
        isOverviewStageSelected: () => isOverviewStageSelected,
        activeStages: () => stages,
        cycleAnalyticsRequestParams: () => cycleAnalyticsRequestParams,
        namespaceRestApiRequestPath: () => namespaceRestApiRequestPath,
        currentValueStreamId: () => valueStream.id,
        isProjectNamespace: () => isProjectNamespace,
      },
      mutations: {
        setSelectedStage: (rootState, value) => {
          // eslint-disable-next-line no-param-reassign
          rootState.selectedStage = value;
        },
      },
    });

    const apolloProvider = createMockApollo([
      [getValueStreamStageMetricsQuery, valueStreamStageMetricsResponseHandler],
    ]);

    wrapper = shallowMount(DurationChartLoader, {
      store,
      apolloProvider,
      provide: { glFeatures: { vsaStageTimeScatterChart: true, ...features } },
    });
    return waitForPromises();
  };

  const findOverviewChart = () => wrapper.findComponent(OverviewChart);
  const findStageChart = () => wrapper.findComponent(StageChart);
  const findStageScatterChart = () => wrapper.findComponent(StageScatterChart);

  const mockApiData = () => {
    // The first 2 stages have different duration values,
    // all subsequent requests should get the same data
    mock
      .onGet(endpoints.durationData)
      .replyOnce(HTTP_STATUS_OK, transformedDurationData[0].data)
      .onGet(endpoints.durationData)
      .replyOnce(HTTP_STATUS_OK, transformedDurationData[1].data)
      .onGet(endpoints.durationData)
      .reply(HTTP_STATUS_OK, transformedDurationData[2].data);
  };

  const stagesRestApiRequests = stages.map((stage) =>
    expect.objectContaining({
      url: `/${namespaceRestApiRequestPath}/-/analytics/value_stream_analytics/value_streams/1/stages/${stage.id}/average_duration_chart`,
      params: cycleAnalyticsRequestParams,
    }),
  );

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('fetches chart data', () => {
    describe('default', () => {
      beforeEach(() => {
        valueStreamStageMetricsQueryHandler = jest
          .fn()
          .mockResolvedValue(mockGroupValueStreamStageMetricsResponse);
        mockApiData();

        return createWrapper({
          valueStreamStageMetricsResponseHandler: valueStreamStageMetricsQueryHandler,
        });
      });

      it('fetches overview chart data', () => {
        expect(mock.history.get).toEqual(stagesRestApiRequests);
      });

      it('does not fetch stage scatter chart data', () => {
        expect(valueStreamStageMetricsQueryHandler).not.toHaveBeenCalled();
      });
    });

    describe.each`
      isProjectNamespace | singlePageResponse                            | paginatedResponse
      ${true}            | ${mockProjectValueStreamStageMetricsResponse} | ${mockProjectValueStreamStageMetricsPaginatedResponse}
      ${false}           | ${mockGroupValueStreamStageMetricsResponse}   | ${mockGroupValueStreamStageMetricsPaginatedResponse}
    `(
      'individual stage selected and isProjectNamespace=$isProjectNamespace',
      ({ isProjectNamespace, singlePageResponse, paginatedResponse }) => {
        beforeEach(() => {
          valueStreamStageMetricsQueryHandler = jest.fn().mockResolvedValue(singlePageResponse);
          mockApiData();

          return createWrapper({
            isOverviewStageSelected: false,
            valueStreamStageMetricsResponseHandler: valueStreamStageMetricsQueryHandler,
            isProjectNamespace,
          });
        });

        it('fetches stage scatter chart data', () => {
          expect(valueStreamStageMetricsQueryHandler).toHaveBeenCalledTimes(1);
          expect(valueStreamStageMetricsQueryHandler).toHaveBeenCalledWith(
            defaultValueStreamStageMetricsParams(isProjectNamespace),
          );
        });

        it('does not fetch overview chart data', () => {
          expect(mock.history.get).toHaveLength(0);
        });

        describe('with additional page of data', () => {
          beforeEach(() => {
            valueStreamStageMetricsQueryHandler = jest
              .fn()
              .mockResolvedValueOnce(paginatedResponse)
              .mockResolvedValueOnce(singlePageResponse);
            mockApiData();

            return createWrapper({
              isOverviewStageSelected: false,
              valueStreamStageMetricsResponseHandler: valueStreamStageMetricsQueryHandler,
              isProjectNamespace,
            });
          });

          it('fetches stage scatter chart data correct number of times', () => {
            expect(valueStreamStageMetricsQueryHandler).toHaveBeenCalledTimes(2);

            expect(valueStreamStageMetricsQueryHandler).toHaveBeenNthCalledWith(
              1,
              defaultValueStreamStageMetricsParams(isProjectNamespace),
            );
            expect(valueStreamStageMetricsQueryHandler).toHaveBeenNthCalledWith(2, {
              ...defaultValueStreamStageMetricsParams(isProjectNamespace),
              endCursor: 'GL',
            });
          });
        });

        describe('selected stage changes', () => {
          const [, newStage] = stages;

          beforeEach(async () => {
            wrapper.vm.$store.commit('setSelectedStage', newStage);

            await waitForPromises();
          });

          it('fetches scatter chart data for new stage', () => {
            expect(valueStreamStageMetricsQueryHandler).toHaveBeenCalledTimes(2);
            expect(valueStreamStageMetricsQueryHandler).toHaveBeenCalledWith({
              ...defaultValueStreamStageMetricsParams(isProjectNamespace),
              stageId: `gid://gitlab/Analytics::CycleAnalytics::Stage/${newStage.id}`,
            });
          });

          it('does not fetch overview chart data', () => {
            expect(mock.history.get).toHaveLength(0);
          });
        });
      },
    );
  });

  describe('overview chart', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('shows the loading state', () => {
        expect(findOverviewChart().props('isLoading')).toBe(true);
      });
    });

    describe('when error is thrown', () => {
      beforeEach(() => {
        mock.onGet(endpoints.durationData).reply(HTTP_STATUS_NOT_FOUND);
        return createWrapper();
      });

      it('shows the error message', () => {
        expect(findOverviewChart().props('errorMessage')).toBe(
          'Request failed with status code 404',
        );
      });
    });

    describe('no data', () => {
      beforeEach(() => {
        mock.onGet(endpoints.durationData).reply(HTTP_STATUS_OK, []);
        return createWrapper();
      });

      it('shows an empty chart', () => {
        expect(findOverviewChart().props('plottableData')).toEqual([]);
      });
    });

    describe('with data', () => {
      beforeEach(() => {
        mockApiData();
        return createWrapper();
      });

      it('shows the chart with the plottable data', () => {
        expect(findOverviewChart().props()).toMatchObject({
          isLoading: false,
          errorMessage: '',
          plottableData: expect.arrayContaining(durationOverviewChartPlottableData),
        });
      });

      it('does not show the stage chart', () => {
        expect(findStageChart().exists()).toBe(false);
      });

      it('does not show the stage scatter chart', () => {
        expect(findStageScatterChart().exists()).toBe(false);
      });
    });
  });

  describe('stage scatter chart', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createWrapper({
          isOverviewStageSelected: false,
          valueStreamStageMetricsResponseHandler: jest.fn().mockReturnValue(new Promise(() => {})),
        });
      });

      it('shows the loading state', () => {
        expect(findStageScatterChart().props('isLoading')).toBe(true);
      });
    });

    describe('when error is thrown', () => {
      const error = new Error('Something went wrong');

      beforeEach(() => {
        return createWrapper({
          isOverviewStageSelected: false,
          valueStreamStageMetricsResponseHandler: jest.fn().mockRejectedValue(error),
        });
      });

      it('renders an alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was an error while fetching data for the stage time chart.',
          error,
          captureError: true,
        });
      });

      it('passes error message to chart', () => {
        expect(findStageScatterChart().props('errorMessage')).toBe('Something went wrong');
      });

      it('does not show chart in loading state', () => {
        expect(findStageScatterChart().props('isLoading')).toBe(false);
      });
    });

    describe('with data', () => {
      beforeEach(() => {
        valueStreamStageMetricsQueryHandler = jest
          .fn()
          .mockResolvedValue(mockGroupValueStreamStageMetricsResponse);

        return createWrapper({
          isOverviewStageSelected: false,
          valueStreamStageMetricsResponseHandler: valueStreamStageMetricsQueryHandler,
        });
      });

      it('shows the chart with plottable data', () => {
        expect(findStageScatterChart().props()).toMatchObject({
          stageTitle: selectedStage.title,
          issuableType: 'Issue',
          plottableData: expect.arrayContaining([
            ['2025-04-29T04:47:24Z', '58606000'],
            ['2025-04-29T05:09:00Z', '668182000'],
          ]),
          isLoading: false,
          startDate: new Date('2018-12-15'),
          endDate: new Date('2019-01-14'),
        });
      });

      it('does not show the overview chart', () => {
        expect(findOverviewChart().exists()).toBe(false);
      });

      it('does not show stage line chart', () => {
        expect(findStageChart().exists()).toBe(false);
      });

      describe('additional page of data', () => {
        beforeEach(() => {
          valueStreamStageMetricsQueryHandler = jest
            .fn()
            .mockResolvedValueOnce(mockGroupValueStreamStageMetricsPaginatedResponse)
            .mockResolvedValueOnce(mockGroupValueStreamStageMetricsResponse);

          return createWrapper({
            isOverviewStageSelected: false,
            valueStreamStageMetricsResponseHandler: valueStreamStageMetricsQueryHandler,
          });
        });

        it('shows the chart with plottable data from all pages', () => {
          expect(findStageScatterChart().props()).toMatchObject({
            stageTitle: selectedStage.title,
            issuableType: 'Issue',
            plottableData: expect.arrayContaining([
              ['2025-04-13T04:33:20Z', '719706000'],
              ['2025-04-16T16:28:27Z', '1019305000'],
              ['2025-04-29T04:47:24Z', '58606000'],
              ['2025-04-29T05:09:00Z', '668182000'],
            ]),
            isLoading: false,
            startDate: new Date('2018-12-15'),
            endDate: new Date('2019-01-14'),
          });
        });
      });
    });

    describe('with no data', () => {
      beforeEach(() => {
        return createWrapper({
          isOverviewStageSelected: false,
          valueStreamStageMetricsResponseHandler: jest
            .fn()
            .mockResolvedValue(mockValueStreamStageMetricsNoDataResponse),
        });
      });

      it('shows an empty chart', () => {
        expect(findStageScatterChart().props()).toMatchObject({
          stageTitle: selectedStage.title,
          plottableData: [],
          isLoading: false,
        });
      });

      it('does not show the overview chart', () => {
        expect(findOverviewChart().exists()).toBe(false);
      });

      it('does not show stage line chart', () => {
        expect(findStageChart().exists()).toBe(false);
      });
    });
  });

  describe('`vsaStageTimeScatterChart` feature flag is disabled', () => {
    describe('fetches chart data', () => {
      beforeEach(() => {
        valueStreamStageMetricsQueryHandler = jest
          .fn()
          .mockResolvedValue(mockGroupValueStreamStageMetricsResponse);

        mockApiData();
        return createWrapper({
          valueStreamStageMetricsResponseHandler: valueStreamStageMetricsQueryHandler,
          features: { vsaStageTimeScatterChart: false },
        });
      });

      it('when the component is created', () => {
        expect(mock.history.get).toEqual(stagesRestApiRequests);
        expect(valueStreamStageMetricsQueryHandler).not.toHaveBeenCalled();
      });

      it('when the selectedStage changes', async () => {
        const [, newStage] = stages;
        wrapper.vm.$store.commit('setSelectedStage', newStage);

        await waitForPromises();

        expect(mock.history.get).toEqual([...stagesRestApiRequests, ...stagesRestApiRequests]);
        expect(valueStreamStageMetricsQueryHandler).not.toHaveBeenCalled();
      });
    });

    describe('stage chart', () => {
      describe('when loading', () => {
        beforeEach(() => {
          createWrapper({
            isOverviewStageSelected: false,
            features: { vsaStageTimeScatterChart: false },
          });
        });

        it('shows the loading state', () => {
          expect(findStageChart().props('isLoading')).toBe(true);
        });
      });

      describe('when error is thrown', () => {
        beforeEach(() => {
          mock.onGet(endpoints.durationData).reply(HTTP_STATUS_NOT_FOUND);
          return createWrapper({
            isOverviewStageSelected: false,
            features: { vsaStageTimeScatterChart: false },
          });
        });

        it('shows the error message', () => {
          expect(findStageChart().props('errorMessage')).toBe(
            'Request failed with status code 404',
          );
        });
      });

      describe('no data', () => {
        beforeEach(() => {
          mock.onGet(endpoints.durationData).reply(HTTP_STATUS_OK, []);
          return createWrapper({
            isOverviewStageSelected: false,
            features: { vsaStageTimeScatterChart: false },
          });
        });

        it('shows an empty chart', () => {
          expect(findStageChart().props('plottableData')).toEqual([]);
        });
      });

      describe('with data', () => {
        beforeEach(() => {
          mockApiData();
          return createWrapper({
            isOverviewStageSelected: false,
            features: { vsaStageTimeScatterChart: false },
          });
        });

        it('shows the chart with the plottable data', () => {
          expect(findStageChart().props()).toMatchObject({
            stageTitle: selectedStage.title,
            isLoading: false,
            errorMessage: '',
            plottableData: expect.arrayContaining([
              ['2019-01-01', 1134000],
              ['2019-01-02', 2321000],
            ]),
          });
        });

        it('does not show the overview chart', () => {
          expect(findOverviewChart().exists()).toBe(false);
        });

        it('does not show the stage scatter chart', () => {
          expect(findStageScatterChart().exists()).toBe(false);
        });
      });
    });
  });
});
