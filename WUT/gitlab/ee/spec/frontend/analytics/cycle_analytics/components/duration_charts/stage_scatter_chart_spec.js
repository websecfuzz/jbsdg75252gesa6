import { GlChartLegend, GlDiscreteScatterChart } from '@gitlab/ui/dist/charts';
import { GlAlert } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StageScatterChart from 'ee/analytics/cycle_analytics/components/duration_charts/stage_scatter_chart.vue';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import NoDataAvailableState from 'ee/analytics/cycle_analytics/components/no_data_available_state.vue';
import { TYPENAME_ISSUE, TYPENAME_MERGE_REQUEST } from '~/graphql_shared/constants';
import { allowedStages as stages } from '../../mock_data';

describe('StageScatterChart', () => {
  let wrapper;
  let mockChartInstance;

  const [{ title: stageTitle }] = stages;

  const chartTitle = `Stage time: ${stageTitle}`;

  const startDate = new Date('2025-05-19');
  const endDate = new Date('2025-05-21');

  const plottableData = [
    ['May 19, 2025', 6.95],
    ['May 20, 2025', 7.58],
    ['May 21, 2025', 8.58],
  ];

  const timeInStageSeries = {
    type: 'scatter',
    name: 'Time in stage',
    data: plottableData,
  };

  const mockTimeInStageStyles = {
    color: 'blue',
  };

  const mockChartOptionSeries = [{ ...timeInStageSeries, lineStyle: mockTimeInStageStyles }];

  const createWrapper = ({ props = {} } = {}) => {
    mockChartInstance = {
      on: jest.fn(),
      off: jest.fn(),
      getDom: () => {
        return {
          getAttribute: jest.fn(),
        };
      },
      getOption: () => {
        return {
          series: mockChartOptionSeries,
        };
      },
      setOption: jest.fn(),
    };

    wrapper = shallowMountExtended(StageScatterChart, {
      propsData: {
        stageTitle,
        startDate,
        endDate,
        ...props,
      },
      stubs: {
        GlChartLegend,
      },
    });
  };

  const findScatterChart = () => wrapper.findComponent(GlDiscreteScatterChart);
  const findChartLegend = () => wrapper.findComponent(GlChartLegend);
  const findLoader = () => wrapper.findComponent(ChartSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findComponent(NoDataAvailableState);

  const emitChartCreated = () => findScatterChart().vm.$emit('created', mockChartInstance);

  describe('when loading', () => {
    beforeEach(() => {
      createWrapper({ props: { isLoading: true } });
    });

    it('renders loader', () => {
      expect(findLoader().exists()).toBe(true);
    });

    it('does not render chart title', () => {
      expect(wrapper.findByText(chartTitle).exists()).toBe(false);
    });

    it('does not render chart', () => {
      expect(findScatterChart().exists()).toBe(false);
    });

    it('does not render chart legend', () => {
      expect(findChartLegend().exists()).toBe(false);
    });

    it('does not render empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not render error alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when there is an error', () => {
    beforeEach(() => {
      createWrapper({ props: { errorMessage: 'Something went wrong' } });
    });

    it('renders an alert', () => {
      expect(findAlert().props()).toMatchObject({
        variant: 'danger',
        dismissible: false,
      });
      expect(findAlert().text()).toBe('Something went wrong');
    });

    it('renders the stage title', () => {
      expect(wrapper.findByText(chartTitle).exists()).toBe(true);
    });

    it('does not render chart', () => {
      expect(findScatterChart().exists()).toBe(false);
    });

    it('does not render chart legend', () => {
      expect(findChartLegend().exists()).toBe(false);
    });

    it('does not render empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not render loader', () => {
      expect(findLoader().exists()).toBe(false);
    });
  });

  describe.each([true, false])('when there is plottable data and isLoading=%s', (isLoading) => {
    beforeEach(() => {
      createWrapper({ props: { plottableData, isLoading } });
    });

    it('renders the stage title', () => {
      expect(wrapper.findByText(chartTitle).exists()).toBe(true);
    });

    it.each`
      issuableType              | expectedSeriesName
      ${TYPENAME_ISSUE}         | ${'Issue time in stage'}
      ${TYPENAME_MERGE_REQUEST} | ${'Merge request time in stage'}
      ${undefined}              | ${'Work item time in stage'}
    `(
      `sets the chart's data correctly when issuableType=$issuableType`,
      ({ issuableType, expectedSeriesName }) => {
        createWrapper({ props: { plottableData, issuableType } });

        expect(findScatterChart().props('data')).toEqual([
          { ...timeInStageSeries, name: expectedSeriesName },
        ]);
      },
    );

    it(`sets the chart's axis labels correctly`, () => {
      expect(findScatterChart().props()).toMatchObject({
        xAxisTitle: 'Date',
        yAxisTitle: 'Duration',
      });
    });

    it(`sets the chart's options correctly`, () => {
      const expectedChartOptions = {
        yAxis: {
          type: 'value',
          axisLabel: {
            formatter: expect.any(Function),
          },
        },
        xAxis: {
          type: 'category',
          data: ['May 19, 2025', 'May 20, 2025', 'May 21, 2025'],
        },
      };

      expect(findScatterChart().props('option')).toEqual(expectedChartOptions);
    });

    it('renders chart legend', async () => {
      const { type, name } = timeInStageSeries;

      emitChartCreated();

      await nextTick();

      expect(findChartLegend().props()).toMatchObject({
        chart: mockChartInstance,
        seriesInfo: expect.arrayContaining([{ type, name, ...mockTimeInStageStyles }]),
      });
    });

    it('does not render empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not render loader', () => {
      expect(findLoader().exists()).toBe(false);
    });

    it('does not render error alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when there is no plottable data', () => {
    beforeEach(() => {
      createWrapper({ props: { plottableData: [[new Date(), null]] } });
    });

    it('renders empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
    });

    it('does not render chart', () => {
      expect(findScatterChart().exists()).toBe(false);
    });

    it('does not render chart legend', () => {
      expect(findChartLegend().exists()).toBe(false);
    });

    it('does not render loader', () => {
      expect(findLoader().exists()).toBe(false);
    });

    it('does not render error alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });
});
