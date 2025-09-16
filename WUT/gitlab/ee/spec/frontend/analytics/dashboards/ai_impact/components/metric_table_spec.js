import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlTooltip } from '@gitlab/ui';
import { GlSparklineChart } from '@gitlab/ui/dist/charts';
import {
  FLOW_METRICS,
  DORA_METRICS,
  VULNERABILITY_METRICS,
  MERGE_REQUEST_METRICS,
  CONTRIBUTOR_METRICS,
  AI_METRICS,
} from '~/analytics/shared/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  DASHBOARD_LOADING_FAILURE,
  CHART_LOADING_FAILURE,
} from 'ee/analytics/dashboards/constants';
import FlowMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/flow_metrics.query.graphql';
import DoraMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/dora_metrics.query.graphql';
import VulnerabilitiesQuery from 'ee/analytics/dashboards/ai_impact/graphql/vulnerabilities.query.graphql';
import MergeRequestsQuery from 'ee/analytics/dashboards/graphql/merge_requests.query.graphql';
import ContributorCountQuery from 'ee/analytics/dashboards/graphql/contributor_count.query.graphql';
import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import MetricTable from 'ee/analytics/dashboards/ai_impact/components/metric_table.vue';
import {
  SUPPORTED_FLOW_METRICS,
  SUPPORTED_DORA_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
  SUPPORTED_MERGE_REQUEST_METRICS,
  SUPPORTED_CONTRIBUTOR_METRICS,
  SUPPORTED_AI_METRICS,
} from 'ee/analytics/dashboards/ai_impact/constants';
import MetricTableCell from 'ee/analytics/dashboards/components/metric_table_cell.vue';
import TrendIndicator from 'ee/analytics/dashboards/components/trend_indicator.vue';
import { setLanguage } from 'jest/__helpers__/locale_helper';
import { AI_IMPACT_TABLE_TRACKING_PROPERTY } from 'ee/analytics/analytics_dashboards/constants';
import {
  mockGraphqlMergeRequestsResponse,
  mockGraphqlContributorCountResponse,
} from '../../helpers';
import { mockMergeRequestsResponseData, mockContributorCountResponseData } from '../../mock_data';
import {
  mockDoraMetricsResponse,
  mockFlowMetricsResponse,
  mockVulnerabilityMetricsResponse,
  mockAiMetricsResponse,
} from '../helpers';
import {
  mockTableValues,
  mockTableLargeValues,
  mockTableBlankValues,
  mockTableZeroValues,
  mockTableAndChartValues,
} from '../mock_data';

const mockTypePolicy = {
  Query: { fields: { project: { merge: false }, group: { merge: false } } },
};
const mockGlAbilities = {
  readDora4Analytics: true,
  readCycleAnalytics: true,
  readSecurityResource: true,
};

Vue.use(VueApollo);

describe('Metric table', () => {
  let wrapper;

  const namespace = 'test-namespace';
  const isProject = false;

  const createMockApolloProvider = ({
    flowMetricsRequest = mockFlowMetricsResponse(mockTableAndChartValues),
    doraMetricsRequest = mockDoraMetricsResponse(mockTableAndChartValues),
    vulnerabilityMetricsRequest = mockVulnerabilityMetricsResponse(mockTableAndChartValues),
    mrMetricsRequest = mockGraphqlMergeRequestsResponse(mockMergeRequestsResponseData),
    contributorMetricsRequest = mockGraphqlContributorCountResponse(
      mockContributorCountResponseData,
    ),
    aiMetricsRequest = mockAiMetricsResponse(mockTableAndChartValues),
  } = {}) => {
    return createMockApollo(
      [
        [FlowMetricsQuery, flowMetricsRequest],
        [DoraMetricsQuery, doraMetricsRequest],
        [VulnerabilitiesQuery, vulnerabilityMetricsRequest],
        [MergeRequestsQuery, mrMetricsRequest],
        [ContributorCountQuery, contributorMetricsRequest],
        [AiMetricsQuery, aiMetricsRequest],
      ],
      {},
      {
        typePolicies: mockTypePolicy,
      },
    );
  };

  const createMockApolloProviderLargeValues = ({
    flowMetricsRequest = mockFlowMetricsResponse(mockTableLargeValues),
    doraMetricsRequest = mockDoraMetricsResponse(mockTableLargeValues),
    vulnerabilityMetricsRequest = mockVulnerabilityMetricsResponse(mockTableLargeValues),
    mrMetricsRequest = mockGraphqlMergeRequestsResponse(mockMergeRequestsResponseData),
    contributorMetricsRequest = mockGraphqlContributorCountResponse(
      mockContributorCountResponseData,
    ),
    aiMetricsRequest = mockAiMetricsResponse(mockTableLargeValues),
  } = {}) => {
    return createMockApollo(
      [
        [FlowMetricsQuery, flowMetricsRequest],
        [DoraMetricsQuery, doraMetricsRequest],
        [VulnerabilitiesQuery, vulnerabilityMetricsRequest],
        [MergeRequestsQuery, mrMetricsRequest],
        [ContributorCountQuery, contributorMetricsRequest],
        [AiMetricsQuery, aiMetricsRequest],
      ],
      {},
      {
        typePolicies: mockTypePolicy,
      },
    );
  };

  const createWrapper = ({
    props = {},
    glAbilities = {},
    glFeatures = {},
    apolloProvider = createMockApolloProvider(),
  } = {}) => {
    wrapper = mountExtended(MetricTable, {
      apolloProvider,
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        namespace,
        isProject,
        ...props,
      },
      provide: {
        glAbilities: {
          ...mockGlAbilities,
          ...glAbilities,
        },
        glFeatures: {
          duoRcaUsageRate: true,
          ...glFeatures,
        },
      },
    });

    return waitForPromises();
  };

  const deploymentFrequencyTestId = 'ai-impact-metric-deployment-frequency';
  const changeFailureRateTestId = 'ai-impact-metric-change-failure-rate';
  const cycleTimeTestId = 'ai-impact-metric-cycle-time';
  const leadTimeTestId = 'ai-impact-metric-lead-time';
  const medianTimeToMergeTestId = 'ai-impact-metric-median-time-to-merge';
  const vulnerabilityCriticalTestId = 'ai-impact-metric-vulnerability-critical';
  const mergeRequestThroughputTestId = 'ai-impact-metric-merge-request-throughput';
  const contributorCountTestId = 'ai-impact-metric-contributor-count';
  const codeSuggestionsUsageRateTestId = 'ai-impact-metric-code-suggestions-usage-rate';
  const codeSuggestionsAcceptanceRateTestId = 'ai-impact-metric-code-suggestions-acceptance-rate';
  const duoChatUsageRateTestId = 'ai-impact-metric-duo-chat-usage-rate';
  const duoRcaUsageRateTestId = 'ai-impact-metric-duo-rca-usage-rate';

  const findTableRow = (rowTestId) => wrapper.findByTestId(rowTestId);
  const findMetricTableCell = (rowTestId) => findTableRow(rowTestId).findComponent(MetricTableCell);
  const findValueTableCells = (rowTestId) =>
    findTableRow(rowTestId).findAll(`[data-testid="ai-impact-table-value-cell"]`);
  const findTrendIndicator = (rowTestId) => findTableRow(rowTestId).findComponent(TrendIndicator);
  const findSparklineChart = (rowTestId) => findTableRow(rowTestId).findComponent(GlSparklineChart);
  const findSkeletonLoaders = (rowTestId) =>
    wrapper.findAll(`[data-testid="${rowTestId}"] [data-testid="metric-skeleton-loader"]`);
  const findChartSkeletonLoader = (rowTestId) =>
    wrapper.find(`[data-testid="${rowTestId}"] [data-testid="metric-chart-skeleton"]`);
  const findMetricNoChangeLabel = (rowTestId) =>
    wrapper.find(`[data-testid="${rowTestId}"] [data-testid="metric-cell-no-change"]`);
  const findMetricNoChangeTooltip = (rowTestId) =>
    getBinding(findMetricNoChangeLabel(rowTestId).element, 'gl-tooltip');

  beforeEach(() => {
    // Needed due to a deprecation in the GlSparkline API:
    // https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2119
    // eslint-disable-next-line no-console
    console.warn = jest.fn();
  });

  describe.each`
    identifier                                     | testId                                 | requestPath  | trackingProperty
    ${DORA_METRICS.DEPLOYMENT_FREQUENCY}           | ${deploymentFrequencyTestId}           | ${namespace} | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${DORA_METRICS.CHANGE_FAILURE_RATE}            | ${changeFailureRateTestId}             | ${namespace} | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${FLOW_METRICS.CYCLE_TIME}                     | ${cycleTimeTestId}                     | ${namespace} | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${FLOW_METRICS.LEAD_TIME}                      | ${leadTimeTestId}                      | ${namespace} | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${FLOW_METRICS.MEDIAN_TIME_TO_MERGE}           | ${medianTimeToMergeTestId}             | ${namespace} | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${VULNERABILITY_METRICS.CRITICAL}              | ${vulnerabilityCriticalTestId}         | ${namespace} | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${MERGE_REQUEST_METRICS.THROUGHPUT}            | ${mergeRequestThroughputTestId}        | ${namespace} | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${CONTRIBUTOR_METRICS.COUNT}                   | ${contributorCountTestId}              | ${namespace} | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE}      | ${codeSuggestionsUsageRateTestId}      | ${''}        | ${''}
    ${AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE} | ${codeSuggestionsAcceptanceRateTestId} | ${''}        | ${''}
    ${AI_METRICS.DUO_CHAT_USAGE_RATE}              | ${duoChatUsageRateTestId}              | ${''}        | ${''}
    ${AI_METRICS.DUO_RCA_USAGE_RATE}               | ${duoRcaUsageRateTestId}               | ${''}        | ${''}
  `('for the $identifier table row', ({ identifier, testId, requestPath, trackingProperty }) => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the metric name', () => {
      expect(findMetricTableCell(testId).props()).toEqual(
        expect.objectContaining({ identifier, requestPath, isProject, trackingProperty }),
      );
    });
  });

  describe.each`
    identifier                                     | name                                    | testId
    ${DORA_METRICS.DEPLOYMENT_FREQUENCY}           | ${'Deployment frequency'}               | ${deploymentFrequencyTestId}
    ${DORA_METRICS.CHANGE_FAILURE_RATE}            | ${'Change failure rate'}                | ${changeFailureRateTestId}
    ${FLOW_METRICS.CYCLE_TIME}                     | ${'Cycle time'}                         | ${cycleTimeTestId}
    ${FLOW_METRICS.LEAD_TIME}                      | ${'Lead time'}                          | ${leadTimeTestId}
    ${FLOW_METRICS.MEDIAN_TIME_TO_MERGE}           | ${'Median time to merge'}               | ${medianTimeToMergeTestId}
    ${VULNERABILITY_METRICS.CRITICAL}              | ${'Critical vulnerabilities over time'} | ${vulnerabilityCriticalTestId}
    ${MERGE_REQUEST_METRICS.THROUGHPUT}            | ${'Merge request throughput'}           | ${mergeRequestThroughputTestId}
    ${CONTRIBUTOR_METRICS.COUNT}                   | ${'Contributor count'}                  | ${contributorCountTestId}
    ${AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE}      | ${'Code Suggestions: Usage'}            | ${codeSuggestionsUsageRateTestId}
    ${AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE} | ${'Code Suggestions: Acceptance rate'}  | ${codeSuggestionsAcceptanceRateTestId}
    ${AI_METRICS.DUO_CHAT_USAGE_RATE}              | ${'Duo Chat: Usage'}                    | ${duoChatUsageRateTestId}
    ${AI_METRICS.DUO_RCA_USAGE_RATE}               | ${'Duo RCA: Usage'}                     | ${duoRcaUsageRateTestId}
  `('for the $identifier table row', ({ name, testId }) => {
    describe('when loading data', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders a skeleton loader in each cell', () => {
        // Metric count + 1 for the trend indicator
        const loadingCellCount = Object.keys(mockTableValues).length + 1;
        expect(findSkeletonLoaders(testId)).toHaveLength(loadingCellCount);
      });

      it('renders a skeleton loader for the sparkline chart', () => {
        expect(findChartSkeletonLoader(testId).exists()).toBe(true);
      });
    });

    describe('when the data fails to load', () => {
      beforeEach(() => {
        return createWrapper({
          apolloProvider: createMockApolloProvider({
            flowMetricsRequest: jest.fn().mockRejectedValue({}),
            doraMetricsRequest: jest.fn().mockRejectedValue({}),
            vulnerabilityMetricsRequest: jest.fn().mockRejectedValue({}),
            mrMetricsRequest: jest.fn().mockRejectedValue({}),
            contributorMetricsRequest: jest.fn().mockRejectedValue({}),
            aiMetricsRequest: jest.fn().mockRejectedValue({}),
          }),
        });
      });

      it('emits `set-alerts` with table and chart warnings', () => {
        expect(wrapper.emitted('set-alerts')).toHaveLength(1);
        expect(wrapper.emitted('set-alerts')[0][0].warnings).toHaveLength(2);
      });

      it('lists name of the failed metric in the table metrics warning', () => {
        const [tableMetrics] = wrapper.emitted('set-alerts')[0][0].warnings;
        expect(tableMetrics).toContain(DASHBOARD_LOADING_FAILURE);
        expect(tableMetrics).toContain(name);
      });

      it('lists name of the failed metric in the chart metrics warning', () => {
        const [, chartMetrics] = wrapper.emitted('set-alerts')[0][0].warnings;
        expect(chartMetrics).toContain(CHART_LOADING_FAILURE);
        expect(chartMetrics).toContain(name);
      });
    });

    describe('when the data is loaded', () => {
      beforeEach(() => {
        return createWrapper();
      });

      it('does not render loading skeletons', () => {
        expect(findSkeletonLoaders(testId)).toHaveLength(0);

        expect(findChartSkeletonLoader(testId).exists()).toBe(false);
      });

      it('renders the metric values', () => {
        const metricCells = findValueTableCells(testId).wrappers;
        expect(metricCells.map((w) => w.text().replace(/\s+/g, ' '))).toMatchSnapshot();
      });

      it('renders the sparkline chart with expected props', () => {
        expect(findSparklineChart(testId).exists()).toBe(true);
        expect(findSparklineChart(testId).props()).toMatchSnapshot();
      });
    });
  });

  describe('change %', () => {
    describe('when there is no data', () => {
      beforeEach(() => {
        return createWrapper({
          apolloProvider: createMockApolloProvider({
            doraMetricsRequest: mockDoraMetricsResponse(mockTableBlankValues),
          }),
        });
      });

      it('renders n/a instead of a percentage', () => {
        expect(findMetricNoChangeLabel(deploymentFrequencyTestId).text()).toBe('n/a');
      });

      it('renders a tooltip on the change cell', () => {
        expect(findMetricNoChangeTooltip(deploymentFrequencyTestId).value).toBe(
          'No data available',
        );
      });
    });

    describe('when there is blank data', () => {
      beforeEach(() => {
        return createWrapper({
          apolloProvider: createMockApolloProvider({
            doraMetricsRequest: mockDoraMetricsResponse(mockTableZeroValues),
          }),
        });
      });

      it('renders n/a instead of a percentage', () => {
        expect(findMetricNoChangeLabel(deploymentFrequencyTestId).text()).toBe('0.0%');
      });

      it('renders a tooltip on the change cell', () => {
        expect(findMetricNoChangeTooltip(deploymentFrequencyTestId).value).toBe('No change');
      });
    });

    describe('when there is a change', () => {
      beforeEach(() => {
        return createWrapper();
      });

      it('does not invert the trend indicator for ascending metrics', () => {
        expect(findTrendIndicator(deploymentFrequencyTestId).props().change).toBe(1);
        expect(findTrendIndicator(deploymentFrequencyTestId).props().invertColor).toBe(false);
      });

      it('inverts the trend indicator for declining metrics', () => {
        expect(findTrendIndicator(changeFailureRateTestId).props().change).toBe(1);
        expect(findTrendIndicator(changeFailureRateTestId).props().invertColor).toBe(true);
      });
    });
  });

  describe('metric tooltips', () => {
    const hoverClasses = ['gl-cursor-pointer', 'hover:gl-underline'];

    beforeEach(() => {
      return createWrapper();
    });

    it('adds hover class and tooltip to code suggestions metric', () => {
      const metricCell = findValueTableCells(codeSuggestionsUsageRateTestId).at(0);
      const metricValue = metricCell.find('[data-testid="formatted-metric-value"]');

      expect(metricCell.findComponent(GlTooltip).exists()).toBe(true);
      expect(metricValue.classes().some((c) => hoverClasses.includes(c))).toBe(true);
    });

    it('does not add hover class and tooltip to other metrics', () => {
      const metricCell = findValueTableCells(leadTimeTestId).at(0);
      const metricValue = metricCell.find('[data-testid="formatted-metric-value"]');

      expect(metricCell.findComponent(GlTooltip).exists()).toBe(false);
      expect(metricValue.classes().some((c) => hoverClasses.includes(c))).toBe(false);
    });
  });

  describe('restricted metrics', () => {
    beforeEach(() => {
      return createWrapper({
        glAbilities: { readDora4Analytics: false },
      });
    });

    it.each([deploymentFrequencyTestId, changeFailureRateTestId])(
      'does not render the `%s` metric',
      (testId) => {
        expect(findTableRow(testId).exists()).toBe(false);
      },
    );

    it('emits `set-alerts` warning with the restricted metrics', () => {
      expect(wrapper.emitted('set-alerts')).toHaveLength(1);
      expect(wrapper.emitted('set-alerts')[0][0]).toEqual({
        canRetry: false,
        warnings: [],
        alerts: expect.arrayContaining([
          'You have insufficient permissions to view: Deployment frequency, Change failure rate',
        ]),
      });
    });
  });

  describe('excludeMetrics set', () => {
    const flowMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const doraMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const vulnerabilityMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const mrMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const contributorMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const aiMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    let apolloProvider;

    beforeEach(() => {
      apolloProvider = createMockApolloProvider({
        flowMetricsRequest,
        doraMetricsRequest,
        vulnerabilityMetricsRequest,
        mrMetricsRequest,
        contributorMetricsRequest,
        aiMetricsRequest,
      });
    });

    describe.each([
      {
        group: 'DORA metrics',
        excludeMetrics: SUPPORTED_DORA_METRICS,
        testIds: [deploymentFrequencyTestId, changeFailureRateTestId],
        apiRequest: doraMetricsRequest,
      },
      {
        group: 'Flow metrics',
        excludeMetrics: SUPPORTED_FLOW_METRICS,
        testIds: [cycleTimeTestId, leadTimeTestId, medianTimeToMergeTestId],
        apiRequest: flowMetricsRequest,
      },
      {
        group: 'Vulnerability metrics',
        excludeMetrics: SUPPORTED_VULNERABILITY_METRICS,
        testIds: [vulnerabilityCriticalTestId],
        apiRequest: vulnerabilityMetricsRequest,
      },
      {
        group: 'MR metrics',
        excludeMetrics: SUPPORTED_MERGE_REQUEST_METRICS,
        testIds: [mergeRequestThroughputTestId],
        apiRequest: mrMetricsRequest,
      },
      {
        group: 'Contribution metrics',
        excludeMetrics: SUPPORTED_CONTRIBUTOR_METRICS,
        testIds: [contributorCountTestId],
        apiRequest: contributorMetricsRequest,
      },
      {
        group: 'AI metrics',
        excludeMetrics: SUPPORTED_AI_METRICS,
        testIds: [codeSuggestionsUsageRateTestId],
        apiRequest: aiMetricsRequest,
      },
    ])('for $group', ({ excludeMetrics, testIds, apiRequest }) => {
      describe('when all metrics excluded', () => {
        beforeEach(() => {
          return createWrapper({ apolloProvider, props: { excludeMetrics } });
        });

        it.each(testIds)('does not render `%s`', (id) => {
          expect(findTableRow(id).exists()).toBe(false);
        });

        it('does not send a request', () => {
          expect(apiRequest).not.toHaveBeenCalled();
        });
      });

      describe('when almost all metrics excluded', () => {
        beforeEach(() => {
          return createWrapper({
            apolloProvider,
            props: { excludeMetrics: excludeMetrics.slice(1) },
          });
        });

        it('requests metrics', () => {
          expect(apiRequest).toHaveBeenCalled();
        });
      });
    });
  });

  describe('`duoRcaUsageRate` feature flag is disabled', () => {
    beforeEach(() => {
      return createWrapper({
        glFeatures: { duoRcaUsageRate: false },
      });
    });

    it(`does not render ${AI_METRICS.DUO_RCA_USAGE_RATE}`, () => {
      expect(findTableRow(duoRcaUsageRateTestId).exists()).toBe(false);
    });
  });

  describe('i18n', () => {
    describe.each`
      language   | formattedValue
      ${'en-US'} | ${'5,000'}
      ${'de-DE'} | ${'5.000'}
    `('When the language is $language', ({ formattedValue, language }) => {
      beforeEach(() => {
        setLanguage(language);
        return createWrapper({ apolloProvider: createMockApolloProviderLargeValues() });
      });

      it('formats numbers correctly', () => {
        expect(findTableRow('ai-impact-metric-vulnerability-critical').html()).toContain(
          formattedValue,
        );
      });
    });
  });
});
